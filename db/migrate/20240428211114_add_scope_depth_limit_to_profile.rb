class AddScopeDepthLimitToProfile < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :scope_depth_limit, :integer, default: SCNR::Engine::Options.scope.depth_limit
  end
end
