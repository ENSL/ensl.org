module UsersHelper
  def sort_link text, param
    key = param
    key += "_reverse" if params[:sort] == param

    options = {
      :url => {:params => params.merge({:sort => key, :page => nil})},
      :with => "`_method=get`",
      :update => 'usersTable',
      :before => "Element.show('spinner')",
      :success => "Element.hide('spinner')",
    }

    html_options = {
      :title => "Sort by this field",
      :href => url_for(:params => params.merge({:sort => key, :page => nil})),
    }

    # link_to_remote text, options, html_options
  end

  def steamid_tool
    df = DataFile.where("name LIKE '%SteamID Finder%'").first
    df ? data_file_url(df) : "/"
  end
end
