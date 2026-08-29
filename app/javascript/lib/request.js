import { post, destroy } from "@rails/request.js"

// Thin wrapper over @rails/request.js (which handles CSRF, credentials and JSON encoding) that
// adds this app's convention: failures come back as { error: "..." } and are raised, so callers
// can just try/catch instead of inspecting every response.
async function perform(verb, url, body) {
  const response = await verb(url, { body: body, responseKind: "json" })
  if (response.ok) return response.json

  const json = await response.json.catch(() => ({}))
  throw new Error(json.error || "Request failed")
}

export function postJSON(url, body = {}) {
  return perform(post, url, body)
}

export function destroyJSON(url, body = {}) {
  return perform(destroy, url, body)
}
