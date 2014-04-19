$(document).ready(function(){
  //
  //function showNews(source, cat, content){
  //    new Ajax.Updater(content, '/categories/' + cat, {
  //        method: 'get'
  //    });
  //    var thisChild = source.parentNode.firstChild;
  //    while (thisChild != source.parentNode.lastChild) {
  //        if (thisChild.nodeType == 1 && thisChild.getAttribute("class") != "unread") {
  //            thisChild.setAttribute("class", "");
  //        }
  //        thisChild = thisChild.nextSibling;
  //    }
  //    source.setAttribute("class", "active");
  //}

  //function goToTheEnd(){
  //    var ed = tinyMCE.activeEditor;
  //    // This gets the root node of the editor window
  //    var root = ed.dom.getRoot();
  //    // And this gets the last node inside of it, so the last <p>...</p> tag
  //    var lastnode = root.childNodes[root.childNodes.length - 1];
  //
  //    if (tinymce.isGecko) {
  //        // But firefox places the selection outside of that tag, so we need to go one level deeper:
  //        lastnode = lastnode.childNodes[lastnode.childNodes.length - 1];
  //    }
  //    // Now, we select the node
  //    ed.selection.select(lastnode);
  //    // And collapse the selection to the end to put the caret there:
  //    ed.selection.collapse(false);
  //}
  //
  //var myrules = {
  //    '.remove': function(e){
  //        el = Event.findElement(e);
  //        target = el.href.replace(/.*#/, '.')
  //        el.up(target).hide();
  //        if (hidden_input = el.previous("input[type=hidden]")) {
  //            hidden_input.value = '1'
  //        }
  //    }
  //};
  //
  //Event.observe(window, 'load', function(){
  //    $('container').delegate('click', myrules);
  //});
  //
  //function changeCssClass(id, newclass){
  //    var obj = document.getElementById(id)
  //    obj.setAttribute("class", newclass);
  //    obj.setAttribute("className", newclass);
  //    obj.className = newclass;
  //};
  //
  //function changeTab(container, tab){
  //    $(tab).style.visibility = 'hidden';
  //};
  //
  //function Trash(source){
  //	var input = document.createElement("input");
  //  input.name = "deleted[reason]";
  //  input.type = "hidden";
  //  input.value = prompt('Enter reason', 'Violation of rule #');
  //	if (input.value == null) {
  //  	return
  //  }
  //  source.appendChild(input);
  //	source.submit();
  //}


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

  // Shoutbox
  $.PeriodicalUpdater("/shoutmsgs/index.js", {
    method: "GET",
    type: "script",
    minTimeout: 10000,
    multiplier: 2
  });
});

$(function() {
  var menuContests;
  var menuGather;
  var menuMaterial;
  var menuForums;

  $(function() {
    $('div#indexMenu div.contests').hover(function(){
    });
  });

  $("div#shoutbox").bind("mousewheel",function(ev, delta) {
      var scrollTop = $(this).scrollTop();
      $(this).scrollTop(scrollTop-Math.round(delta));
  });

  // Gather stuff

  $("a#gather-info-hide").live('click', function() {
    $("div#gather-info").fadeOut('slow', 0);
  });

  $("a#gatherJoinBtn").live('click', function() {
    $('form#new_gatherer').submit();
  });

  // Submit TODO

  $("a.submit").live('click', function() {
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
  $("#users th a, #users .pagination a").live("click", function() {
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
