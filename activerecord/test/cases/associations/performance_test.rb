# frozen_string_literal: true

require "cases/helper"
require "cases/encryption/helper"
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

class AssociationsPerformanceTest < ActiveRecord::TestCase
  include ActiveRecord::Encryption::PerformanceHelpers

  fixtures :authors, :books, :citations, :readers, :posts, :references, :comments, :ratings,
    :categories, :categorizations, :tags, :taggings, :people, :clubs, :members, :memberships,
    :sponsors, :developers, :projects, :developers_projects, :computers, :companies, :accounts

  DURATION = 10

  def test_performance_tree_code_only
    baseline = lambda do
      ENV["SLIM_PATCH_CODE_ONLY"] = nil
      ENV["SLIM_PATCH"] = nil
      authors = Author.includes(
        :books, { posts: :special_comments }, { categorizations: :category }
      ).order("comments.body").where("posts.id = 4")
      authors.to_a
    end

    assert_slower_by_at_most 1.05, baseline: baseline, duration: DURATION do
      ENV["SLIM_PATCH_CODE_ONLY"] = "true"
      ENV["SLIM_PATCH"] = nil
      authors = Author.includes(
        :books, { posts: :special_comments }, { categorizations: :category }
      ).order("comments.body").where("posts.id = 4")
      authors.to_a
    end
  end

  def test_performance_objects_allocating
    baseline = lambda do
      ENV["SLIM_PATCH_CODE_ONLY"] = nil
      ENV["SLIM_PATCH"] = nil
      authors = Author.includes(
        :books, { posts: :special_comments }, { categorizations: :category }
      ).order("comments.body").where("posts.id = 4")
      authors.to_a
    end

    assert_slower_by_at_most 1.2, baseline: baseline, duration: DURATION do
      ENV["SLIM_PATCH_CODE_ONLY"] = nil
      ENV["SLIM_PATCH"] = "true"
      authors = Author.includes(
        :books, { posts: :special_comments }, { categorizations: :category }
      ).order("comments.body").where("posts.id = 4")
      authors.to_a
    end
  end

  def test_performance_sql_only
    baseline = lambda do
      ENV["SLIM_PATCH_CODE_ONLY"] = nil
      ENV["SLIM_PATCH"] = nil
      authors = Author.includes(
        :books, { posts: :special_comments }, { categorizations: :category }
      ).order("comments.body").where("posts.id = 4")
      authors.to_sql
    end

    assert_slower_by_at_most 0.7, baseline: baseline, duration: DURATION do
      ENV["SLIM_PATCH_CODE_ONLY"] = nil
      ENV["SLIM_PATCH"] = "true"
      authors = Author.includes(
        :books, { posts: :special_comments }, { categorizations: :category }
      ).order("comments.body").where("posts.id = 4")
      authors.to_sql
    end
  end
end
