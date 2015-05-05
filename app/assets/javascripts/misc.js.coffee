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

  $('#steam-search a').click (event) ->
    event.preventDefault()

    $search = $('#steam-search')
    id = $search.data 'user-id'

    $search.html "<p>Searching...</p>"

    $.get "/api/v1/users/#{id}", (data) ->
      $search.html "<a href='#{data.steam.url}'>Steam Profile: #{data.steam.nickname}</a>"