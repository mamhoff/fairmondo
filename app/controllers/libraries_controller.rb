# -*- coding: utf-8 -*-
#
#
# == License:
# Fairmondo - Fairmondo is an open-source online marketplace.
# Copyright (C) 2013 Fairmondo eG
#
# This file is part of Fairmondo.
#
# Fairmondo is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Fairmondo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Fairmondo.  If not, see <http://www.gnu.org/licenses/>.
#
class LibrariesController < ApplicationController
  helper_method :user_focused?

  respond_to :html

  before_filter :set_user, if: :user_focused?, only: :index
  before_filter :set_library, only: [:show, :update, :destroy, :admin_audit]

  # Authorization
  skip_before_filter :authenticate_user!, only: [:index, :show]

  def index
    # Build empty Library object if user creates a new library
    @library = @user.libraries.build if user_signed_in? && user_focused?

    if user_signed_in? || index_mode != 'myfavorite'
      @libraries = LibraryPolicy::Scope.new(current_user, @user, focus.includes(user: [:image])).resolve.page(params[:page]).per(12)
    end

    respond_to do |format|
      format.html
    end
  end

  def show
    authorize @library
    respond_with @library do |format|
      format.js
    end
  end

  def create
    @library = current_user.libraries.build(params.for(Library).refine)
    authorize @library

    # Ist article-Id vorhanden?
    @article_id ||= params[:article_id]

    # Both .js responses are only for the articles view!
    respond_with @library do |format|
      if @library.save
        format.html { redirect_to user_libraries_path(current_user, anchor: "library#{@library.id}") }
        format.js
      else
        format.html { redirect_to user_libraries_path(current_user), alert: @library.errors.values.first.first }
        format.js { render :new }
      end
    end
  end

  def update
    authorize @library
    if @library.update(params.for(@library).refine)
      redirect_to user_libraries_path(current_user, anchor: "library#{@library.id}")
    else
      redirect_to user_libraries_path(current_user), alert: @library.errors.values.first.first
    end
  end

  def destroy
    authorize @library
    @library.destroy
    redirect_to user_libraries_path(current_user)
  end

  # for admins to quickly add one or more articles to any library
  def admin_add
    library = Library.where(exhibition_name: params[:library][:exhibition_name]).first
    authorize library

    if params[:library][:exhibition_name] && (params[:library][:articles] || params[:library][:article_id])
      articles = params[:library][:articles] || [params[:library][:article_id]]

      begin
        articles.each do |id|
          library.articles << Article.find(id) if id.present?
        end
        notice = {notice: "Added to library."}
      rescue => err #will throw errors e.g. if library already had that article
        notice = {error: "Something went wrong: #{err.to_s}"} # Only visible for admins
      end
    end
    redirect_to :back, flash: notice
  end

  #for admins to quickly remove an article from a featured library
  def admin_remove
    library = Library.where(exhibition_name: params[:exhibition_name]).first
    authorize library

    article = Article.find(params[:article_id])
    library.articles.delete article
    redirect_to :back, notice: "Deleted from library."
  end

  # for admins to audit libraries for display on the welcome page
  def admin_audit
    authorize @library
    @library.update_column :audited, !@library.audited
    respond_with @library do |format|
      format.js { render 'admin_audit' }
    end
  end

  private

    def set_library
      @library = Library.find(params[:id])
    end

    def set_user
      @user = User.find(params[:user_id])
    end

    def user_focused?
      params.has_key?(:user_id)
    end

    def focus
      if user_focused?
        @user.libraries
      else
        case index_mode
        when 'new'
          Library
        when 'myfavorite'
          current_user.hearted_libraries.reorder('hearts.created_at DESC')
        else
          Library.trending
        end
      end
    end

    # Configure the libraries collection that is displayed
    def index_mode
      @mode ||= params[:mode] || 'trending'
    end
end
