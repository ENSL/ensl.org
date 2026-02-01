function bindMiscHandlers() {
  $(document).off('click', '#logout-link');
  $(document).on('click', '#logout-link', function (e) {
    e.preventDefault();
    $('#logout-form').submit();
  });

  $('select').each(function (_i, el) {
    var $select = $(el);
    if ($select.parent().hasClass('select-wrapper')) return;

    $select.wrap('<div class="select-wrapper" />');
    $select.off('DOMSubtreeModified');
    $select.on('DOMSubtreeModified', function () {
      var $el = $(this);
      var $wrapper = $el.parent();

      if ($el.is('[disabled]')) {
        $wrapper.addClass('disabled');
      } else {
        $wrapper.removeClass('disabled');
      }
    });

    $select.trigger('DOMSubtreeModified');
  });

  $(document).off('click', 'a[href=\\#form_submit]');
  $(document).on('click', 'a[href=\\#form_submit]', function () {
    $(this).closest('form').submit();
    return false;
  });

  $(document).off('change', 'select.autosubmit');
  $(document).on('change', 'select.autosubmit', function () {
    $(this).closest('form').submit();
  });

  $('#notification').delay(3000).fadeOut();

  $(document).off('click', '#steam-search a');
  $(document).on('click', '#steam-search a', function (event) {
    event.preventDefault();

    var $search = $('#steam-search');
    var id = $search.data('user-id');

    $search.html('<p>Searching...</p>');

    $.get('/api/v1/users/' + id, function (data) {
      $search.html("<a href='" + data.steam.url + "'>Steam Profile: " + data.steam.nickname + '</a>');
    });
  });
}

$(function () {
  bindMiscHandlers();
  $(document).on('turbo:load', function () {
    bindMiscHandlers();
  });
});