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
class LibraryPolicy < Struct.new(:user, :library)

  def create?
    own?
  end

  def update?
    own? || admin?
  end

  def destroy?
    own?
  end

  def show?
    library.public? || own? || admin?
  end

  def admin_add?
    admin?
  end

  def admin_remove?
    admin?
  end

  def admin_audit?
    admin?
  end

  private
    def own?
      user && user.id == library.user_id
    end

    def admin?
      User.is_admin? user
    end

  class Scope < Struct.new(:current_user, :user, :scope)
    def resolve
      included_scope = scope.includes(comments: [:user, :commentable])

      if user && (user.is? current_user)
        included_scope
      else
        included_scope.published.not_empty
      end
    end
  end
end
