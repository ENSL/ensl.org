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
  $(document).off('mousewheel', 'div#shoutbox');
  $(document).on('mousewheel', 'div#shoutbox', function(ev, delta) {
    var scrollTop = $(this).scrollTop();
    $(this).scrollTop(scrollTop-Math.round(delta));
  });

  // Forums fast reply
  $(document).off('click', 'a.fastReply');
  $(document).on('click', 'a.fastReply', function() {
    $('#reply').fadeIn('fast',
    function() {
      $(this).focus();
      $("a.fastReply").hide();
    });
  });

  // Gather stuff

  $(document).off('click', 'a#gather-info-hide');
  $(document).on('click', 'a#gather-info-hide', function() {
    $("div#gather-info").fadeOut('slow', 0);
  });

  $(document).off('click', 'a.delete-gatherer');
  $(document).on('click', 'a.delete-gatherer', function(e) {
    e.preventDefault();
    var formId = $(this).data('form-id');
    var form = document.getElementById(formId);
    if (form) {
      form.submit();
    }
  });

  $(document).off('click', 'a.vote-link');
  $(document).on('click', 'a.vote-link', function(e) {
    e.preventDefault();
    var url = $(this).data('url') || this.href;
    var $shared = $('#vote_form');
    if ($shared.length && url) {
      $shared.attr('action', url);
      $shared[0].submit();
    }
  });

  // Submit TODO

  $(document).off('click', 'a.submit');
  $(document).on('click', 'a.submit', function() {
    $(this).closest('form').submit()
  });

  $(document).off('submit', 'form.new_shoutmsg');
  $(document).on('submit', 'form.new_shoutmsg', function(){
    $('input[type=submit]', this).attr('disabled', 'disabled');
  });

  $(document).off('ajax:complete', 'form.new_shoutmsg');
  $(document).on("ajax:complete", 'form.new_shoutmsg', function(event, xhr, status){
    var self = this;

    $(this)[0].reset();

    setTimeout(function() {
      $('input[type=submit]', self).removeAttr('disabled');
    }, 2000);
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

  $(document).off('keyup', '#users_search input');
  $(document).on('keyup', '#users_search input', function() {
    $.get($("#users_search").attr("action"), $("#users_search").serialize(), null, "script");
    return false;
  });

  // Poll page
  $(document).off('click', 'a#option');
  $(document).on('click', 'a#option', function() {
  });
  
  // Match proposal

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

// Bind steam-login anchors: prefer submitting a hidden Rails form if present
$(function() {
  $(document).on('click', 'a.steam-login', function(e) {
    e.preventDefault();
    var hidden = document.getElementById('steam-auth-form');
    if (hidden) {
      hidden.submit();
      return;
    }
  });
});
