const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 8080;
const MAX_PLAYERS = 6;
const LOBBY_TIMER = 20; // secondes

// ─── État global ─────────────────────────────────────────────────────────────
// rooms: Map<roomId, { players: Map<ws, {id, name, slot}>, timer, countdown, started }>
const rooms = new Map();
// ws → roomId
const clientRoom = new Map();
// ws → { id, name }
const clientInfo = new Map();

let nextId = 1;

// ─── Serveur HTTP (health check pour Render) ────────────────────────────────
const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Uma Relay OK");
});

const wss = new WebSocketServer({ server });

wss.on("connection", (ws) => {
  const id = String(nextId++);
  clientInfo.set(ws, { id, name: "Player" });
  console.log(`[+] Client ${id} connecté (total: ${wss.clients.size})`);

  ws.on("message", (raw) => {
    try {
      const data = JSON.parse(raw);
      handleMessage(ws, data);
    } catch (e) {
      console.error("JSON invalide:", e.message);
    }
  });

  ws.on("close", () => {
    console.log(`[-] Client ${clientInfo.get(ws)?.id} déconnecté`);
    handleDisconnect(ws);
    clientInfo.delete(ws);
  });

  ws.on("error", (err) => {
    console.error("WS error:", err.message);
  });
});

// Heartbeat toutes les 30s pour éviter le timeout Render
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.readyState === ws.OPEN) ws.ping();
  });
}, 30000);

// ─── Gestion des messages ───────────────────────────────────────────────────

function handleMessage(ws, data) {
  switch (data.type) {
    case "find_match":
      handleFindMatch(ws, data);
      break;
    case "lane_change":
      handleRelay(ws, data);
      break;
    case "skill_use":
      handleRelay(ws, data);
      break;
    case "leave":
      handleDisconnect(ws);
      break;
    default:
      console.log("Message inconnu:", data.type);
  }
}

function handleFindMatch(ws, data) {
  const info = clientInfo.get(ws);
  info.name = data.player_name || "Player";

  // Chercher une room non-started avec de la place
  let targetRoom = null;
  for (const [roomId, room] of rooms) {
    if (!room.started && room.players.size < MAX_PLAYERS) {
      targetRoom = roomId;
      break;
    }
  }

  // Créer une nouvelle room si aucune dispo
  if (!targetRoom) {
    targetRoom = "room_" + Date.now();
    rooms.set(targetRoom, {
      players: new Map(),
      timer: null,
      countdown: LOBBY_TIMER,
      started: false,
    });
    console.log(`[Room] Nouvelle room: ${targetRoom}`);
  }

  const room = rooms.get(targetRoom);
  const slot = room.players.size;
  room.players.set(ws, { id: info.id, name: info.name, slot });
  clientRoom.set(ws, targetRoom);

  // Envoyer confirmation au joueur
  send(ws, { type: "joined", player_id: info.id, room_id: targetRoom });

  // Mettre à jour tout le lobby
  broadcastLobbyUpdate(targetRoom);

  // Lancer le timer dès le premier joueur
  if (!room.timer) {
    startRoomCountdown(targetRoom);
  }

  // Si la room est pleine, lancer immédiatement
  if (room.players.size >= MAX_PLAYERS) {
    clearInterval(room.timer);
    room.timer = null;
    startRace(targetRoom);
  }
}

function handleRelay(ws, data) {
  const roomId = clientRoom.get(ws);
  if (!roomId) return;
  const room = rooms.get(roomId);
  if (!room) return;
  const info = clientInfo.get(ws);

  // Relayer à tous les autres joueurs de la room
  for (const [client] of room.players) {
    if (client !== ws && client.readyState === client.OPEN) {
      send(client, { ...data, player_id: info.id });
    }
  }
}

function handleDisconnect(ws) {
  const roomId = clientRoom.get(ws);
  if (!roomId) return;
  const room = rooms.get(roomId);
  if (!room) {
    clientRoom.delete(ws);
    return;
  }

  const info = clientInfo.get(ws);
  room.players.delete(ws);
  clientRoom.delete(ws);

  // Prévenir les autres
  for (const [client] of room.players) {
    if (client.readyState === client.OPEN) {
      send(client, { type: "player_left", player_id: info?.id });
    }
  }

  // Si la room est vide, la supprimer
  if (room.players.size === 0) {
    clearInterval(room.timer);
    rooms.delete(roomId);
    console.log(`[Room] Room ${roomId} supprimée (vide)`);
  } else if (!room.started) {
    broadcastLobbyUpdate(roomId);
  }
}

// ─── Room logic ─────────────────────────────────────────────────────────────

function startRoomCountdown(roomId) {
  const room = rooms.get(roomId);
  if (!room) return;

  room.countdown = LOBBY_TIMER;
  room.timer = setInterval(() => {
    room.countdown--;
    broadcastLobbyUpdate(roomId);

    if (room.countdown <= 0) {
      clearInterval(room.timer);
      room.timer = null;
      startRace(roomId);
    }
  }, 1000);
}

function startRace(roomId) {
  const room = rooms.get(roomId);
  if (!room || room.started) return;

  room.started = true;
  const raceSeed = Math.floor(Math.random() * 2147483647);

  const playersArr = [];
  for (const [, info] of room.players) {
    playersArr.push({ id: info.id, name: info.name, slot: info.slot });
  }

  for (const [client] of room.players) {
    if (client.readyState === client.OPEN) {
      send(client, { type: "race_start", seed: raceSeed, players: playersArr });
    }
  }

  console.log(
    `[Room] Race lancée dans ${roomId} (seed=${raceSeed}, ${playersArr.length} joueurs)`
  );
}

function broadcastLobbyUpdate(roomId) {
  const room = rooms.get(roomId);
  if (!room) return;

  const playersArr = [];
  for (const [, info] of room.players) {
    playersArr.push({ id: info.id, name: info.name, slot: info.slot });
  }

  for (const [client] of room.players) {
    if (client.readyState === client.OPEN) {
      send(client, {
        type: "lobby_update",
        players: playersArr,
        time_remaining: room.countdown,
      });
    }
  }
}

function send(ws, data) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

// ─── Start ──────────────────────────────────────────────────────────────────

server.listen(PORT, () => {
  console.log(`Uma Relay démarré sur le port ${PORT}`);
});
