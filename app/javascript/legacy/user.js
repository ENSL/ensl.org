let userInfoTimeout

// Legacy/inactive user-hover popup: hides the popup when delayed close fires.
function hideUserPopupRunner() {
  const popup = document.getElementById("userPopup")
  if (popup) popup.style.visibility = "hidden"
}

// Legacy/inactive user-hover popup: positions popup and fetches popup JS payload.
export function ShowUserPopup(source, user) {
  clearTimeout(userInfoTimeout)

  const popup = document.getElementById("userPopup")
  if (!popup || !source) return

  popup.style.top = `${source.offsetTop}px`
  popup.style.left = `${source.offsetLeft - 170}px`
  popup.style.visibility = "visible"

  $.ajax({
    type: "GET",
    url: `/users/popup/${user}.js`,
    dataType: "script"
  })
}

// Legacy/inactive user-hover popup: delays hide so cursor can move into popup.
export function HideUserPopup() {
  userInfoTimeout = setTimeout(hideUserPopupRunner, 1000)
}

// User/profile handlers: profile tabs, users index sorting/search, and Steam lookup.
export function bindUserHandlers() {
  const userTabs = $("#user-profile .tabs")
  const timeZoneInput = document.querySelector("[data-browser-time-zone]")

  if (timeZoneInput && !timeZoneInput.value && Intl.DateTimeFormat) {
    timeZoneInput.value = Intl.DateTimeFormat().resolvedOptions().timeZone || ""
  }

  // Switches active tab styling and loads tab content via JS response.
  $(document).off("click", "#user-profile li a")
  $(document).on("click", "#user-profile li a", function() {
    userTabs.find("li").removeClass("activeli")
    $(this).parent().addClass("activeli")

    $.ajax({
      type: "GET",
      url: `${window.location.pathname}.js?page=${$(this).attr("id")}`,
      dataType: "script"
    })
  })

  // Loads users table sorting/pagination links via script response instead of full navigation.
  $(document).off("click", "#users th a, #users .pagination a")
  $(document).on("click", "#users th a, #users .pagination a", function() {
    $.getScript(this.href)
    return false
  })

  // Submits users search as JS on each keyup for live filtering.
  $(document).off("keyup", "#users_search input")
  $(document).on("keyup", "#users_search input", function() {
    $.get($("#users_search").attr("action"), $("#users_search").serialize(), null, "script")
    return false
  })

  // Replaces placeholder with fetched Steam profile link for the viewed user.
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

// Legacy global helper: opens a small user-lookup popup window for older views.
export function findUser(source) {
  const findUserWindow = window.open(`/users/find?source=${source}`, "findUser", "height=400,width=400,menubar=false")
  if (window.focus && findUserWindow) {
    findUserWindow.focus()
  }
  if (findUserWindow && findUserWindow.opener == null) {
    findUserWindow.opener = self
  }
  return false
}
