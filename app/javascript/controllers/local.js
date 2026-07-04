let userInfoTimeout

// Hide the hover popup immediately when the delayed timer fires.
function HideUserPopupRunner() {
  const popup = document.getElementById("userPopup")
  if (popup) popup.style.visibility = "Hidden"
}

// Show the user popup near the hovered element and load its script payload.
function ShowUserPopup(source, user) {
  clearInterval(userInfoTimeout)

  const popup = document.getElementById("userPopup")
  if (!popup || !source) return

  popup.style.top = `${source.offsetTop}px`
  popup.style.left = `${source.offsetLeft - 170}px`
  popup.style.visibility = "Visible"

  $.ajax({
    type: "GET",
    url: `/users/popup/${user}.js`,
    dataType: "script"
  })
}

// Schedule the popup to hide a moment later so the pointer can move into it.
function HideUserPopup() {
  userInfoTimeout = setTimeout(HideUserPopupRunner, 1000)
}

// Refresh the hidden authenticity token so legacy form submissions still pass CSRF checks.
function refreshFormAuthenticityToken(form) {
  if (!form) return

  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  const csrfParam = document.querySelector("meta[name='csrf-param']")?.getAttribute("content") || "authenticity_token"
  if (!csrfToken) return

  let tokenInput = form.querySelector(`input[name='${csrfParam}']`)
  if (!tokenInput) {
    tokenInput = document.createElement("input")
    tokenInput.type = "hidden"
    tokenInput.name = csrfParam
    form.appendChild(tokenInput)
  }

  tokenInput.value = csrfToken
}

// Bind the old jQuery-driven page interactions used across the legacy UI.
function bindLocalHandlers() {
  $(document).off("click", ".fastReply")
  $(document).on("click", ".fastReply", function(e) {
    e.preventDefault()
    $("#reply").fadeIn("fast", function() {
      $(this).find("textarea").focus()
      $(".fastReply").addClass("invisible")
    })
  })

  $(document).off("click", "a#gather-info-hide")
  $(document).on("click", "a#gather-info-hide", function() {
    $("div#gather-info").fadeOut("slow", 0)
  })

  $(document).off("click", "a[data-submit-form]")
  $(document).on("click", "a[data-submit-form]", function(e) {
    e.preventDefault()
    const confirmMessage = $(this).data("confirm")
    if (confirmMessage && !window.confirm(confirmMessage)) {
      return
    }
    const formId = $(this).data("form-id")
    const formSelector = $(this).data("form-selector")
    let form = null

    if (formId) {
      form = document.getElementById(formId)
    } else if (formSelector) {
      form = document.querySelector(formSelector)
    } else {
      form = $(this).closest("form")[0]
    }

    const url = $(this).data("url") || $(this).data("form-action")
    if (form && url) {
      try { form.action = url } catch (_err) { }
    }

    if (form) {
      refreshFormAuthenticityToken(form)
      form.submit()
    }
  })

  const userTabs = $("#user-profile .tabs")

  $(document).off("click", "#user-profile li a")
  $(document).on("click", "#user-profile li a", function() {
    userTabs.find("li").removeClass("activeli")
    $(this).parent().addClass("activeli")

    $.ajax({
      type: "GET",
      url: `${window.location.protocol}//${window.location.host}/${window.location.pathname}.js?page=${$(this).attr("id")}`,
      dataType: "script"
    })
  })

  $(document).off("click", "#users th a, #users .pagination a")
  $(document).on("click", "#users th a, #users .pagination a", function() {
    $.getScript(this.href)
    return false
  })

  $(document).off("keyup", "#users_search input")
  $(document).on("keyup", "#users_search input", function() {
    $.get($("#users_search").attr("action"), $("#users_search").serialize(), null, "script")
    return false
  })

  $(document).off("click", "a#option")
  $(document).on("click", "a#option", function() {})

  $(document).off("click", "form.edit_match_proposal a")
  $(document).on("click", "form.edit_match_proposal a", function() {
    const form = $(this).closest("form.edit_match_proposal")
    form.children("input#match_proposal_status").val($(this).data("id"))
    $.post(form.attr("action"), form.serialize(), function(data) {
      const tr = form.closest("tr")
      tr.children("td").eq(2).text(data.status)
      if (data.status === "Revoked" || data.status === "Rejected") tr.children("td").eq(3).empty()
    }, "json")
      .error(function(err) {
        const errjson = JSON.parse(err.responseText)
        alert(errjson.error.message)
      })
  })

  $("select").each(function(_i, el) {
    const $select = $(el)
    if ($select.parent().hasClass("select-wrapper")) return

    $select.wrap('<div class="select-wrapper" />')
    $select.off("DOMSubtreeModified")
    $select.on("DOMSubtreeModified", function() {
      const $el = $(this)
      const $wrapper = $el.parent()

      if ($el.is("[disabled]")) {
        $wrapper.addClass("disabled")
      } else {
        $wrapper.removeClass("disabled")
      }
    })

    $select.trigger("DOMSubtreeModified")
  })

  $(document).off("change", "select.autosubmit")
  $(document).on("change", "select.autosubmit", function() {
    $(this).closest("form").submit()
  })

  if (!(document.body && document.body.dataset && document.body.dataset.disableFlashFade === "true")) {
    $("#notification").delay(3000).fadeOut()
  }

  $(document).off("click", "#steam-search a")
  $(document).on("click", "#steam-search a", function(event) {
    event.preventDefault()

    const $search = $("#steam-search")
    const id = $search.data("user-id")

    $search.html("<p>Searching...</p>")

    $.get(`/api/v1/users/${id}`, function(data) {
      $search.html(`<a href='${data.steam.url}'>Steam Profile: ${data.steam.nickname}</a>`)
    })
  })
}

// Open the user search popup in a small dedicated window.
function findUser(source) {
  const findUserWindow = window.open(`/users/find?source=${source}`, "findUser", "height=400,width=400,menubar=false")
  if (window.focus && findUserWindow) {
    findUserWindow.focus()
  }
  if (findUserWindow && findUserWindow.opener == null) {
    findUserWindow.opener = self
  }
  return false
}

// Request the quote snippet for the given record and inject the returned script.
function QuoteText(id, type) {
  const quoteType = type || "posts"
  $.ajax({
    type: "GET",
    url: `/${quoteType}/quote/${id}.js`,
    dataType: "script"
  })
}

// Mark nested fields as removed and hide the matching form block.
function remove_fields(link) {
  $(link).prev("input[type=hidden]").val("1")
  $(link).closest(".fields").hide()
}

// Clone a nested field template and replace its placeholder ID with a fresh one.
function add_fields(link, association, content) {
  const newId = new Date().getTime()
  const regexp = new RegExp(`new_${association}`, "g")
  $(link).parent().before(content.replace(regexp, newId))
}

window.ShowUserPopup = ShowUserPopup
window.HideUserPopup = HideUserPopup
window.bindLocalHandlers = bindLocalHandlers
window.findUser = findUser
window.QuoteText = QuoteText
window.remove_fields = remove_fields
window.add_fields = add_fields

// Rebind the legacy handlers on initial load and on Turbo navigation events.
document.addEventListener("DOMContentLoaded", bindLocalHandlers)
document.addEventListener("turbo:load", bindLocalHandlers)
document.addEventListener("turbo:render", bindLocalHandlers)
