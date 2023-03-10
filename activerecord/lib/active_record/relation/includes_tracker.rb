# frozen_string_literal: true

module ActiveRecord
  # Determine includes which are used / not used in refererences and joins.
  module IncludesTracker # :nodoc:
    def includes_values_referenced
      select_includes_values_with_references(:any?, :present?)
    end

    def includes_values_non_referenced
      select_includes_values_with_references(:all?, :blank?)
    end

    private
      def select_includes_values_with_references(matcher, intersect_matcher)
        all_references = (references_values + joins_values + left_outer_joins_values).map(&:to_s)

        normalized_includes_values.select do |includes_value|
          includes_tree = ActiveRecord::Associations::JoinDependency.make_tree(includes_value)

          includes_values_reflections(includes_tree).public_send(matcher) do |reflection|
            next true unless reliable_reflection_match?(reflection)

            (possible_includes_tables(reflection) & all_references).public_send(intersect_matcher)
          end
        end
      end

      def includes_values_reflections(includes_tree)
        includes_reflections = []

        traverse_tree_with_model(includes_tree, self) do |association, model|
          reflection = model.reflect_on_association(association)

          includes_reflections << reflection

          reliable_reflection_match?(reflection) ? reflection.klass : model
        end

        includes_reflections
      end

      def possible_includes_tables(reflection)
        all_possible_includes_tables =
          reflection.collect_join_chain.map(&:table_name) <<
          reflection.alias_candidate(reflection.table_name) <<
          reflection.name.to_s

        if inferable_reflection_table_name?(reflection)
          all_possible_includes_tables <<
            reflection.join_table <<
            join_table_with_postfix_alias(reflection)
        end

        all_possible_includes_tables
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

      def join_table_with_postfix_alias(reflection)
        [reflection.join_table, reflection.alias_candidate(:join)].sort.join("_")
      end

      def normalized_includes_values
        includes_values.map do |element|
          element.is_a?(Hash) ? element.map { |key, value| { key => value } } : element
        end.flatten
      end

      def traverse_tree_with_model(object, model, &block)
        object.each do |key, value|
          next_model = yield(key, model)
          traverse_tree_with_model(value, next_model, &block) if next_model
        end
      end
  end
end
