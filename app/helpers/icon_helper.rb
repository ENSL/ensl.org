# frozen_string_literal: true

module IconHelper
  def fa_icon(name, style: :solid, text: nil, class: nil)
    style_class =
      case style
      when :solid   then 'fa-solid'
      when :regular then 'fa-regular'
      when :brands  then 'fa-brands'
      else 'fa-solid'
      end

    icon_classes = [style_class, "fa-#{name}", binding.local_variable_get(:class)].compact.join(' ')

    icon_tag = content_tag(:i, nil, class: icon_classes)

    return icon_tag unless text

    safe_join([icon_tag, ' ', text])
  end
end
