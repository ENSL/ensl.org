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

$(function() {
  $("div#shoutbox").bind("mousewheel",function(ev, delta) {
    var scrollTop = $(this).scrollTop();
    $(this).scrollTop(scrollTop-Math.round(delta));
  });


  // Forums fast reply
  $("a#fastReply").on('click', function() {
    $('#reply').fadeIn('slow')
  });

  // Gather stuff

  $("a#gather-info-hide").on('click', function() {
    $("div#gather-info").fadeOut('slow', 0);
  });

  $("a#gatherJoinBtn").on('click', function() {
    $('form#new_gatherer').submit();
  });

  // Submit TODO

  $("a.submit").on('click', function() {
    $(this).closest('form').submit()
  });

  $('form.new_shoutmsg').submit(function(){
    $('input[type=submit]', this).attr('disabled', 'disabled');
  });

  $('form.new_shoutmsg').on("ajax:complete", function(event, xhr, status){
    var self = this;

    $(this)[0].reset();

    setTimeout(function() {
      $('input[type=submit]', self).removeAttr('disabled');
    }, 2000);
  });

  $user_tabs = $("#user-profile .tabs");

  // User page
  $("#user-profile li a").click(function() {
    $user_tabs.find("li").removeClass("activeli");
    $(this).parent().addClass("activeli");

    $.ajax({
      type: "GET",
      url: window.location.protocol + "//" + window.location.host + "/" + window.location.pathname + ".js?page=" + $(this).attr('id'),
      dataType: "script"
    });
  });

  // Users page
  $("#users th a, #users .pagination a").on("click", function() {
    $.getScript(this.href);
    return false;
  });

  $("#users_search input").keyup(function() {
    $.get($("#users_search").attr("action"), $("#users_search").serialize(), null, "script");
    return false;
  });

  // Poll page
  $("a#option").click(function() {
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

// Match proposal

$("form.edit_match_proposal a").on('click', function() {
  var form = $(this).closest('form.edit_match_proposal');
  form.children("input#match_proposal_status").val($(this).dataset.id);
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
