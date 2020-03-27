module PollsHelper
  def add_option_link(name, form)
    # FIXME: not used atm.
    link_to_function name do |page|
      option = render :partial => 'option', :locals => { :pf => form, :options => Option.new }
      page << %{
        this.counter = typeof this.counter == 'undefined' ? 0 : this.counter + 1;
        $('options').insert({ bottom: "#{ escape_javascript option }".replace(/\\[\\d+\\]/g, "[" + this.counter + "]") });
      }
    end
  end
end
