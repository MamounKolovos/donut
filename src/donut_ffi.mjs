import { BitArray$BitArray, BitArray$data, Result$Ok, Result$Error } from './gleam.mjs';

let nextId = 0;
/** @type {Map<number, WebSocket>} */
const idToWebsocket = new Map();

/**
 * 
 * @param {string} url 
 * @param {(id: number) => void} handle_open 
 * @param {(id: number, text: string) => void} handle_text 
 * @param {(id: number, bitArray: unknown)} handle_binary 
 * @param {(id: number)} handle_error 
 * @param {(id: number, code: number)} handle_close 
 * @returns 
 */
export function init(
  url,
  handle_open,
  handle_text,
  handle_binary,
  handle_error,
  handle_close
) {
  /** @type {WebSocket} */
  let websocket;

  try {
    websocket = new WebSocket(url);
  } catch {
    return Result$Error(undefined);
  }

  websocket.binaryType = "arraybuffer";

  const id = nextId;
  idToWebsocket.set(id, websocket);
  nextId += 1;

  websocket.onopen = () => {
    handle_open(id);
  }

  websocket.onmessage = (event) => {
    if (typeof event.data == "string") {
      handle_text(id, event.data);
    } else {
      const bitArray = BitArray$BitArray(new Uint8Array(event.data));
      handle_binary(id, bitArray);
    }
  }

  websocket.onerror = () => {
    idToWebsocket.delete(id);
    handle_error(id);
  }

  websocket.onclose = (event) => {
    idToWebsocket.delete(id);
    handle_close(id, event.code);
  }

  return Result$Ok(undefined);
}

/**
 * 
 * @param {number} id 
 * @param {string} text 
 */
export function send_text(id, text) {
  const websocket = idToWebsocket.get(id);
  if (websocket?.readyState == WebSocket.OPEN) {
    websocket.send(text);
  }
}

/**
 * 
 * @param {number} id 
 * @param {unknown} bitArray 
 */
export function send_binary(id, bitArray) {
  const websocket = idToWebsocket.get(id);
  if (websocket?.readyState == WebSocket.OPEN) {
    const bytes = BitArray$data(bitArray);
    websocket.send(bytes);
  }
}

/**
 * 
 * @param {number} id 
 */
export function close(id) {
  const websocket = idToWebsocket.get(id);
  if (websocket) {
    websocket.close();
  }
}