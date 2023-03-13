# frozen_string_literal: true

module ActiveRecord
  # Determine includes which are used / not used in refererences and joins.
  module IncludesTracker # :nodoc:
    TABLE_WITH_POSTFIX_ALIAS = "_join"

    def includes_values_referenced
      select_includes_values_with_references(:present?)
    end

    def includes_values_non_referenced
      select_includes_values_with_references(:blank?)
    end

    private
      def select_includes_values_with_references(intersect_matcher)
        all_references = (references_values + joins_values + left_outer_joins_values).map(&:to_s)

        return includes_values if references_table_with_postfix_alias?(all_references)

        includes_tree = ActiveRecord::Associations::JoinDependency.make_tree(includes_values)
        traverse_tree_with_model(includes_tree, self) do |reflection|
          next true unless reliable_reflection_match?(reflection)

          (possible_includes_tables(reflection) & all_references).public_send(intersect_matcher)
        end
      end

      # Possible includes tables contain:
      # - Current table name;
      # - All `through` table names;
      # - Special plural table name;
      # - Association name (`references` may save directly);
      # - Join table for HABTM.
      def possible_includes_tables(reflection)
        all_possible_includes_tables =
          reflection.collect_join_chain.map(&:table_name) <<
          reflection.alias_candidate(reflection.table_name) <<
          reflection.name.to_s

        if inferable_reflection_table_name?(reflection)
          all_possible_includes_tables << reflection.join_table
        end

        all_possible_includes_tables
      end

      def references_table_with_postfix_alias?(all_references)
        all_references.any? { _1.end_with?(TABLE_WITH_POSTFIX_ALIAS) }
      end

      def reliable_reflection_match?(reflection)
        reflection && inferable_reflection_klass?(reflection)
      end

      def inferable_reflection_klass?(reflection)
        !reflection.polymorphic?
      end

      def inferable_reflection_table_name?(reflection)
        !reflection.through_reflection?
      end

      def traverse_tree_with_model(hash, model, &block)
        return hash if model.nil?

        result = []
        hash.each do |association, nested_hash|
          current = model.reflect_on_association(association)

          next_model = reliable_reflection_match?(current) ? current.klass : nil
          current_result = traverse_tree_with_model(nested_hash, next_model, &block)
          next (result << { association => current_result }) if current_result.any?

          result << association if block.call(current)
        end
        result
      end
  end
end
