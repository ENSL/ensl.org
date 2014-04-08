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
  $("#logout").click ->
    $(this).closest("form").submit()