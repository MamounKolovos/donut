/**
 * 
 * @param {string} id 
 */
export function scroll_into_view(id) {
  const element = document.getElementById(id);
  element?.scrollIntoView({ behavior: "auto" })
}