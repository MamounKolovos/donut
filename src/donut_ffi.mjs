import * as gleam from './gleam.mjs';

let next_id = 0;
/** @type {Map<number, WebSocket>} */
const id_to_websocket = new Map();

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
    return gleam.Result$Error(undefined);
  }

  websocket.binaryType = "arraybuffer";

  const id = next_id;
  id_to_websocket.set(id, websocket);
  next_id += 1;

  websocket.onopen = () => {
    handle_open(id);
  }

  websocket.onmessage = (event) => {
    if (typeof event.data == "string") {
      handle_text(id, event.data);
    } else {
      const bit_array = gleam.BitArray$BitArray(new Uint8Array(event.data));
      handle_binary(id, bit_array);
    }
  }

  websocket.onerror = () => {
    id_to_websocket.delete(id);
    handle_error(id);
  }

  websocket.onclose = (event) => {
    id_to_websocket.delete(id);
    handle_close(id, event.code);
  }

  return gleam.Result$Ok(undefined);
}

/**
 * 
 * @param {number} id 
 * @param {string} text 
 */
export function send_text(id, text) {
  const websocket = id_to_websocket.get(id);
  if (websocket?.readyState == WebSocket.OPEN) {
    websocket.send(text);
  }
}

/**
 * 
 * @param {number} id 
 * @param {unknown} bit_array 
 */
export function send_binary(id, bit_array) {
  const websocket = id_to_websocket.get(id);
  if (websocket?.readyState == WebSocket.OPEN) {
    const bytes = gleam.BitArray$BitArray$data(bit_array);
    websocket.send(bytes);
  }
}

/**
 * 
 * @param {number} id 
 */
export function close(id) {
  const websocket = id_to_websocket.get(id);
  if (websocket) {
    websocket.close(1000);
  }
}