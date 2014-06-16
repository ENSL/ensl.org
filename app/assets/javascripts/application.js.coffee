//= require jquery
//= require jquery_ujs
//= require jquery.periodicalupdater
//= require jquery.jplayer.min
//= require flowplayer
//= require tinymce-jquery
//= require yetii
//= require local
//= require_self

$ ->
  $('#logout').click ->
    $(this).closest('form').submit()

  $('select').each (i, el) ->
    $select = $(el)

    $select.wrap '<div class="select-wrapper" />'
    $select.on 'DOMSubtreeModified', (event) ->
      $el = $(this)
      $wrapper = $el.parent()

      if $el.is("[disabled]")
        $wrapper.addClass 'disabled'
      else
        $wrapper.removeClass 'disabled'

    $select.trigger 'DOMSubtreeModified'

  $('a[href=#form_submit]').click ->
    $(this).closest('form').submit()
    return false

  $('select.autosubmit').change ->
    $(this).closest('form').submit()

  $('#notification').delay(3000).fadeOut()