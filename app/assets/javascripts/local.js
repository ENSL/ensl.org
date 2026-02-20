$(document).ready(function(){
  // User popup
  var userInfoTimeout;

  function ShowUserPopup(source, user){
    clearInterval(userInfoTimeout);

    hp = document.getElementById("userPopup");
    hp.style.top = source.offsetTop + "px";
    hp.style.left = source.offsetLeft - 170 + "px";
    hp.style.visibility = "Visible";

    $.ajax({
       type: "GET",
       url: "/users/popup/" + user + ".js",
       dataType: "script"
     });
  }

  function HideUserPopup(){
      userInfoTimeout = setTimeout("HideUserPopupRunner();", 1000);
  }

  function HideUserPopupRunner(){
    document.getElementById("userPopup").style.visibility = "Hidden";
  }
});

function bindLocalHandlers() {
  // Forums fast reply
  $(document).off('click', '.fastReply');
  $(document).on('click', '.fastReply', function(e) {
    e.preventDefault();
    $('#reply').fadeIn('fast', function() {
      $(this).find('textarea').focus();
      $(".fastReply").addClass('invisible');
    });
  });

  // Gather stuff

  $(document).off('click', 'a#gather-info-hide');
  $(document).on('click', 'a#gather-info-hide', function() {
    $("div#gather-info").fadeOut('slow', 0);
  });

  // Submit TODO (legacy `a.submit` removed — use `data-submit-form` links)

  // Generic link-to-form submitter
  // Usage: <a href="#" data-submit-form data-form-id="my-form">Submit</a>
  // or:    <a href="#" data-submit-form data-form-selector="#my-form">Submit</a>
  $(document).off('click', 'a[data-submit-form]');
  $(document).on('click', 'a[data-submit-form]', function(e) {
    e.preventDefault();
    var confirmMessage = $(this).data('confirm');
    if (confirmMessage && !window.confirm(confirmMessage)) {
      return;
    }
    var formId = $(this).data('form-id');
    var formSelector = $(this).data('form-selector');
    var form = null;

    if (formId) {
      form = document.getElementById(formId);
    } else if (formSelector) {
      form = document.querySelector(formSelector);
    } else {
      form = $(this).closest('form')[0];
    }

    // If the link provides a URL, set the target form's action before submit
    var url = $(this).data('url') || $(this).data('form-action');
    if (form && url) {
      try { form.action = url; } catch (err) { /* ignore */ }
    }

    if (form) {
      form.submit();
    }
  });

  $user_tabs = $("#user-profile .tabs");

  // User page
  $(document).off('click', '#user-profile li a');
  $(document).on('click', '#user-profile li a', function() {
    $user_tabs.find("li").removeClass("activeli");
    $(this).parent().addClass("activeli");

    $.ajax({
      type: "GET",
      url: window.location.protocol + "//" + window.location.host + "/" + window.location.pathname + ".js?page=" + $(this).attr('id'),
      dataType: "script"
    });
  });

  // Users page
  $(document).off('click', '#users th a, #users .pagination a');
  $(document).on("click", "#users th a, #users .pagination a", function() {
    $.getScript(this.href);
    return false;
  });

  // User search
  // Description: Auto-submit user search form on keyup
  $(document).off('keyup', '#users_search input');
  $(document).on('keyup', '#users_search input', function() {
    $.get($("#users_search").attr("action"), $("#users_search").serialize(), null, "script");
    return false;
  });

  // Poll page
  $(document).off('click', 'a#option');
  $(document).on('click', 'a#option', function() {
  });
  
  // Match proposals
  // Description: Handle match proposal status update links
  // in the match proposals list page.
  $(document).off('click', 'form.edit_match_proposal a');
  $(document).on('click', 'form.edit_match_proposal a', function() {
    var form = $(this).closest('form.edit_match_proposal');
    form.children("input#match_proposal_status").val($(this).data('id'));
    $.post(form.attr('action'),form.serialize(), function(data) {
      tr = form.closest('tr');
      tr.children('td').eq(2).text(data.status);
      if(data.status === 'Revoked' || data.status === 'Rejected') tr.children('td').eq(3).empty();
    }, 'json')
      .error(function (err) {
        errjson = JSON.parse(err.responseText);
        alert(errjson.error.message);
      });
    }
  );

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

  $(document).off('change', 'select.autosubmit');
  $(document).on('change', 'select.autosubmit', function () {
    $(this).closest('form').submit();
  });

  if (!(document.body && document.body.dataset && document.body.dataset.disableFlashFade === 'true')) {
    $('#notification').delay(3000).fadeOut();
  }

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

$(function() {
  bindLocalHandlers();
  $(document).on('turbo:load', function() {
    bindLocalHandlers();
  });
});

// User search
var findUserWindow = "";

function findUser(source) {
  findUserWindow = window.open("/users/find?source=" + source, 'findUser', 'height=400,width=400,menubar=false');
  if (window.focus) {
    findUserWindow.focus();
  }
  if (findUserWindow.opener == null) {
    childWindow.opener = self;
  }
  return false;
}

function QuoteText(id, type) {
  type = type || 'posts';

  $.ajax({
    type: "GET",
    url: "/" + type + "/quote/" + id + ".js",
    dataType: "script"
  });
}

// Tooltip to help admin

// Fields removing and adding dynamically

function remove_fields(link) {
  $(link).prev("input[type=hidden]").val("1");
  $(link).closest(".fields").hide();
}

function add_fields(link, association, content) {
  var new_id = new Date().getTime();
  var regexp = new RegExp("new_" + association, "g")
  $(link).parent().before(content.replace(regexp, new_id));
}

showEdit = function (url_id) {
    var parent = $('#' + url_id);
    parent.find('> td').toggleClass('hidden');
};

submitEdit = function (url_id) {
    var parent = $('#' + url_id);
    var form = parent.find('form');

    $.post('<%= custom_urls_path %>/' + url_id, form.serialize())
        .done(function (data) {
            var nameField = parent.children('.name');
            var articleField = parent.children('.article');

            nameField.text(data.obj.name);
            articleField.text(data.obj.title);
            parent.find('> td').toggleClass('hidden');

            alert(data.message);
        }).fail(function (errorRes) {
            var error = JSON.parse(errorRes.responseText);
            alert(error.message);
        });
}
