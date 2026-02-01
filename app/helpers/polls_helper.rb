module PollsHelper
  def add_option_link(name, form)
    # FIXME: not used atm.
    link_to name, '#',
            onclick: '/* add option not implemented in helper; implement add_option_link JS if needed */ return false;'
  end
end
