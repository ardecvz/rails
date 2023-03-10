# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"
require "models/citation"
require "models/reader"
require "models/post"
require "models/reference"
require "models/comment"
require "models/rating"
require "models/category"
require "models/categorization"
require "models/tag"
require "models/tagging"
require "models/person"
require "models/club"
require "models/developer"
require "models/project"
require "models/computer"
require "models/company"
require "models/contract"
require "models/member"
require "models/membership"
require "models/sponsor"

class AssociationsEagerLoadMixingPreloadTest < ActiveRecord::TestCase
  fixtures :authors, :books, :citations, :readers, :posts, :references, :comments, :ratings,
    :categories, :categorizations, :tags, :taggings, :people, :clubs, :members, :memberships,
    :sponsors, :developers, :projects, :developers_projects, :computers, :companies, :accounts

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_has_one_association
    authors = Author.includes(:books, :post).where(post: { type: "Post" })
    assert_left_joins(1) { authors.to_sql }
    assert_queries(2) { authors.to_a }
    assert_no_queries { authors.map(&:post).map(&:title) }
    assert_no_queries { authors.flat_map(&:books).map(&:title) }
  end

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_has_many_association
    authors = Author.includes(:books, :post).where(books: { language: nil })
    assert_left_joins(1) { authors.to_sql }
    assert_queries(2) { authors.to_a }
    assert_no_queries { authors.map(&:post).map(&:title) }
    assert_no_queries { authors.flat_map(&:books).map(&:title) }
  end

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_habtm_association
    developers = Developer.includes(:audit_logs, :shared_computers)
                          .where(shared_computers: { timezone: nil })
    assert_left_joins(2) { developers.to_sql }
    assert_queries(2) { developers.to_a }
    assert_no_queries { developers.flat_map(&:audit_logs).map(&:message) }
    assert_no_queries { developers.flat_map(&:shared_computers).map(&:system) }
  end

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_has_many_through_association
    authors = Author.includes(:ratings, :post).where(ratings: { value: 1 })
    assert_left_joins(3) { authors.to_sql }
    assert_queries(2) { authors.to_a }
    assert_no_queries { authors.map(&:post).map(&:title) }
    assert_no_queries { authors.flat_map(&:ratings).map(&:value) }
  end

  def test_mixing_eager_load_and_preload_for_referenced_only_indirect_through_association
    persons = Person.includes(:posts, :references).references(:readers)
                    .where("readers.id = 1 or 1=1")
    assert_left_joins(2) { persons.to_sql }
    assert_queries(2) { persons.to_a }
    assert_queries(3) { persons.flat_map(&:readers).map(&:skimmer) }
    assert_no_queries { persons.flat_map(&:posts).map(&:title) }
  end

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_second_level_association
    authors = Author.includes(books: :citations).where(citations: { citation_id: nil })
    assert_left_joins(2) { authors.to_sql }
    assert_queries(1) { authors.to_a }
    assert_no_queries { authors.flat_map(&:books).map(&:title) }
    assert_no_queries { authors.flat_map(&:books).flat_map(&:citations).map(&:citation) }
  end

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_several_levels_association
    authors = Author.includes(
      :books, { posts: :special_comments }, { categorizations: :category }
    ).order("comments.body").where("posts.id = 4")
    assert_left_joins(2) { authors.to_sql }
    assert_queries(4) { authors.to_a }
    assert_no_queries do
      authors.first.books.first
      authors.first.posts.first.special_comments.first
      authors.first.categorizations.first.category
    end
  end

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_standard_hash_association
    authors = Author.includes(
      :books, posts: :special_comments, categorizations: :category
    ).order("comments.body").where("posts.id = 4")
    assert_left_joins(2) { authors.to_sql }
    assert_queries(4) { authors.to_a }
    assert_no_queries do
      authors.first.books.first
      authors.first.posts.first.special_comments.first
      authors.first.categorizations.first.category
    end
  end

  def test_mixing_eager_load_and_preload_for_deep_nested_includes
    authors = Author.includes(
      :books, posts: { special_comments: { post: [ :special_comments, :very_special_comment ] } }
    ).order("comments.body", "very_special_comments_posts.body").where("posts.id = 4")
    assert_left_joins(5) { authors.to_sql }
    assert_queries(2) { authors.to_a }
    assert_no_queries do
      authors.first.books.first
      authors.first.posts.first.special_comments.first.post.special_comments
      authors.first.posts.first.special_comments.first.post.very_special_comment
    end
  end

  def test_mixing_eager_load_and_preload_for_includes_with_referenced_single_argument_association
    authors = Author.includes(:books).where(books: { language: nil })
    assert_left_joins(1) { authors.to_sql }
    assert_queries(1) { authors.to_a }
    assert_no_queries { authors.flat_map(&:books).map(&:title) }
  end

  def test_mixing_eager_load_and_preload_for_joined_includes
    posts = Post.includes(:comments, :author).joins(:comments).left_joins(:author)
    assert_left_joins(2) { posts.to_sql }
    assert_queries(1) { posts.to_a }
    assert_no_queries { posts.flat_map(&:comments).map(&:type) }
    assert_no_queries { posts.map(&:author).map(&:name) }
  end

  def test_mixing_eager_load_and_preload_for_eager_loaded_includes
    authors = Author.eager_load(:posts).includes(posts: :special_comments)
    assert_left_joins(1) { authors.to_sql }
    assert_queries(2) { authors.to_a }
    assert_no_queries { authors.flat_map(&:posts).map(&:title) }
    assert_no_queries { authors.flat_map(&:posts).flat_map(&:special_comments).map(&:type) }
  end

  def test_mixing_eager_load_and_preload_for_preloaded_includes
    authors = Author.preload(:posts).includes(posts: :special_comments)
    assert_left_joins(0) { authors.to_sql }
    assert_queries(3) { authors.to_a }
    assert_no_queries { authors.flat_map(&:posts).map(&:title) }
    assert_no_queries { authors.flat_map(&:posts).flat_map(&:special_comments).map(&:type) }
  end

  def test_mixing_eager_load_and_preload_without_eager_loading
    persons = Person.males.includes(:agents)
    assert_left_joins(0) { persons.to_sql }
    assert_queries(2) { persons.to_a }
    assert_no_queries { persons.flat_map(&:agents).map(&:first_name) }
  end

  def test_mixing_eager_load_and_preload_with_forced_full_eager_loading_calculation
    companies = Company.includes(:contracts)
    assert_sql(/LEFT OUTER JOIN/) { companies.sum(:developer_id) }
    assert_queries(1) { companies.sum(:developer_id) }
  end

  def test_mixing_eager_load_and_preload_with_forced_full_eager_loading_pluck
    companies = Company.includes(:contracts)
    assert_sql(/LEFT OUTER JOIN/) { companies.pluck(:developer_id) }
    assert_queries(1) { companies.pluck(:developer_id) }
  end

  def test_mixing_eager_load_and_preload_with_forced_full_eager_loading_ids
    companies = Company.includes(:contracts, account: :firm)
    assert_sql(/LEFT OUTER JOIN/) { companies.ids }
    assert_queries(1) { companies.ids }
  end

  def test_mixing_eager_load_and_preload_with_unreliable_non_existent_reflection_match
    developers = Developer.all
      .includes(:developers_projects)
      .where("developers_projects.joined_on": nil)
    assert_left_joins(1) { developers.to_sql }
    assert_queries(1) { developers.to_a }
  end

  def test_mixing_eager_load_and_preload_with_uninferable_reflection_klass
    assert_raise ActiveRecord::EagerLoadPolymorphicError do
      tags(:general).taggings
        .includes(:taggable).references(:bogus_table)
        .to_a
    end
  end

  def test_mixing_eager_load_and_preload_with_uninferable_reflection_table_name
    members = Member.all
      .includes(:sponsor_club)
      .where("members.name": "Groucho Marx")
      .order("clubs.name")
    assert_left_joins(2) { members.to_sql }
    assert_queries(1) { members.to_a }
    assert_no_queries { members.map(&:sponsor_club).map(&:name) }
  end

  def test_mixing_eager_load_and_preload_table_alias
    firms = Firm.all
      .includes(:clients_using_primary_key)
      .order("clients_using_primary_keys_companies.name")
    assert_left_joins(1) { firms.to_sql }
    assert_queries(1) { firms.to_a }
    assert_no_queries { firms.flat_map(&:clients_using_primary_key).map(&:name) }
  end

  def test_mixing_eager_load_and_preload_join_table
    developers = Developer.all
      .includes(:projects)
      .where("developers_projects.access_level": 1)
    assert_left_joins(2) { developers.to_sql }
    assert_queries(1) { developers.to_a }
    assert_no_queries { developers.flat_map(&:projects).map(&:name) }
  end

  def test_mixing_eager_load_and_preload_join_table_with_postfix_alias
    developers = Developer.all
      .includes(projects: :developers)
      .where("developers_projects_projects_join.access_level.joined_on": nil)
    assert_left_joins(4) { developers.to_sql }
    assert_queries(1) { developers.to_a }
    assert_no_queries { developers.flat_map(&:projects).map(&:name) }
    assert_no_queries { developers.flat_map(&:projects).flat_map(&:developers).map(&:first_name) }
  end

  def test_mixing_eager_load_and_preload_for_cache_key_with_non_referenced_includes
    accounts = Account.includes(:firm)
    assert_sql(/^(?!.*LEFT OUTER JOIN).*/) { accounts.cache_key }
    assert_no_queries { accounts.cache_key }
  end

  def test_mixing_eager_load_and_preload_within_update_all
    accounts = Account.includes(:firm)
    assert_sql(/^(?!.*LEFT OUTER JOIN).*/) { accounts.update_all("firm_name = 1") }
    assert_queries(1) { accounts.update_all("firm_name = 1") }
  end

  def test_mixing_eager_load_and_preload_within_delete_all
    accounts = Account.includes(:firm)
    assert_sql(/^(?!.*LEFT OUTER JOIN).*/) { accounts.delete_all }
    assert_queries(1) { accounts.delete_all }
  end

  def test_mixing_eager_load_and_preload_for_non_existent_association
    projects = Project.includes(:non_existent).references(:non_existent)
    assert_raises(ActiveRecord::ConfigurationError) do
      projects.to_a
    end
  end

  def test_mixing_eager_load_and_preload_for_non_existent_column
    authors = Author.includes(books: :citations).where(citations: { citation: nil })
    assert_raises(ActiveRecord::StatementInvalid) do
      authors.to_a
    end
  end

  private
    def assert_left_joins(num = 1, &block)
      sql = _assert_nothing_raised_or_warn("assert_left_joins", &block)
      count = sql.scan("LEFT OUTER JOIN").count
      msg = "#{count} instead of #{num} LEFT JOINs were included\nSQL:\n#{sql}"
      assert_equal num, count, msg
    end
end
