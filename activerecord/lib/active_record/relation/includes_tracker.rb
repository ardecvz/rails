# frozen_string_literal: true

module ActiveRecord
  # Determine includes which are used / not used in refererences and joins.
  module IncludesTracker # :nodoc:
    def includes_values_referenced
      select_includes_values_with_references(:present?)
    end

    def includes_values_non_referenced
      select_includes_values_with_references(:blank?)
    end

    private
      def select_includes_values_with_references(intersect_matcher)
        all_references = (references_values + joins_values + left_outer_joins_values).map(&:to_s)

        return includes_values if reference_numbered_table_alias?(all_references)

        includes_tree = ActiveRecord::Associations::JoinDependency.make_tree(includes_values)
        traverse_tree_with_model(includes_tree, self) do |reflection, parent_reflection|
          next true unless reliable_reflection_match?(reflection)

          possible_includes_tables = generate_includes_tables(reflection, parent_reflection)
          (possible_includes_tables & all_references).public_send(intersect_matcher)
        end
      end

      # Numbered table aliases bring ambiguity because of the digits at the end.
      def reference_numbered_table_alias?(all_references)
        all_references.any? { |reference| reference.last.between?("0", "9") }
      end

      # Possible includes tables contain:
      # - Current table name;
      # - All `through` table names;
      # - Association name (`references` may set values directly);
      # - Single alias for table;
      # - Join table for HABTM;
      # - Single alias for join table for HABTM.
      def generate_includes_tables(reflection, parent_reflection)
        all_possible_includes_tables =
          reflection.collect_join_chain.map(&:table_name) <<
          reflection.name.to_s <<
          reflection.alias_candidate(reflection.table_name)

        if inferable_reflection_table_name?(reflection)
          all_possible_includes_tables <<
            reflection.join_table <<
            generate_possible_join_table_alias(reflection, parent_reflection)
        end

        all_possible_includes_tables
      end

      def generate_possible_join_table_alias(reflection, parent_reflection)
        return unless parent_reflection

        [reflection.join_table, parent_reflection.alias_candidate(:join)].sort.join("_")
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

      def traverse_tree_with_model(hash, model, parent_reflection = nil, &block)
        return hash unless model

        result = []
        hash.each do |association, nested_hash|
          current = model.reflect_on_association(association)

          next_model = reliable_reflection_match?(current) ? current.klass : nil
          current_result = traverse_tree_with_model(nested_hash, next_model, current, &block)
          next (result << { association => current_result }) if current_result.any?

          result << association if block.call(current, parent_reflection)
        end
        result
      end
  end
end
