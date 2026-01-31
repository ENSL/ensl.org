bindMiscHandlers = ->
  $(document).off 'click', '#logout-link'
  $(document).on 'click', '#logout-link', (e) ->
    e.preventDefault()
    $('#logout-form').submit()

  $('select').each (i, el) ->
    $select = $(el)
    return if $select.parent().hasClass 'select-wrapper'

    $select.wrap '<div class="select-wrapper" />'
    $select.off 'DOMSubtreeModified'
    $select.on 'DOMSubtreeModified', (event) ->
      $el = $(this)
      $wrapper = $el.parent()

      if $el.is("[disabled]")
        $wrapper.addClass 'disabled'
      else
        $wrapper.removeClass 'disabled'

    $select.trigger 'DOMSubtreeModified'

  $(document).off 'click', 'a[href=\\#form_submit]'
  $(document).on 'click', 'a[href=\\#form_submit]', ->
    $(this).closest('form').submit()
    return false

  $(document).off 'change', 'select.autosubmit'
  $(document).on 'change', 'select.autosubmit', ->
    $(this).closest('form').submit()

  $('#notification').delay(3000).fadeOut()

  $(document).off 'click', '#steam-search a'
  $(document).on 'click', '#steam-search a', (event) ->
    event.preventDefault()

    $search = $('#steam-search')
    id = $search.data 'user-id'

    $search.html "<p>Searching...</p>"

    $.get "/api/v1/users/#{id}", (data) ->
      $search.html "<a href='#{data.steam.url}'>Steam Profile: #{data.steam.nickname}</a>"

$ ->
  bindMiscHandlers()
  $(document).on 'turbo:load', ->
    bindMiscHandlers()