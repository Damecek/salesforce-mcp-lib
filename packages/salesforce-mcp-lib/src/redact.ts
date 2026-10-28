/** Bound and flatten text that came from a remote body before it reaches an error message or log. */
export function safeRemoteText(text: string, maxChars = 200): string {
  const flat = text.replace(/[^\x20-\x7E]/g, '?');
  return flat.length > maxChars ? `${flat.slice(0, maxChars)}...` : flat;
}
