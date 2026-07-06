.pragma library

var playerAliases = [
    { match: "spotify", label: "Spotify", priority: 100 },
    { match: "youtube music", label: "YouTube Music", priority: 98 },
    { match: "youtube", label: "YouTube", priority: 96 },
    { match: "chromium", label: "Chromium Media", priority: 86 },
    { match: "chrome", label: "Chrome Media", priority: 86 },
    { match: "firefox", label: "Firefox Media", priority: 82 },
    { match: "vlc", label: "VLC", priority: 70 },
    { match: "mpv", label: "mpv", priority: 70 },
    { match: "elisa", label: "Elisa", priority: 65 },
    { match: "kdeconnect", label: "KDE Connect", priority: 50 },
    { match: "kde connect", label: "KDE Connect", priority: 50 }
]

function playerSearchText(player) {
    if (!player)
        return "";

    return `${player.identity || ""} ${player.desktopEntry || ""} ${player.dbusName || ""}`.toLowerCase();
}

function playerAlias(player) {
    const value = playerSearchText(player);
    for (let i = 0; i < playerAliases.length; i++) {
        if (value.indexOf(playerAliases[i].match) !== -1)
            return playerAliases[i];
    }

    return null;
}

function playerPriority(player) {
    const alias = playerAlias(player);
    return alias ? alias.priority : 0;
}

function choosePlayer(players) {
    if (!players || players.length === 0)
        return null;

    let best = players[0];
    let bestPriority = playerPriority(best);

    for (let i = 0; i < players.length; i++) {
        const priority = playerPriority(players[i]);
        if (priority > bestPriority) {
            best = players[i];
            bestPriority = priority;
        }
    }

    return best;
}

function displayPlayer(player) {
    if (!player)
        return "Media";

    const alias = playerAlias(player);
    if (alias)
        return alias.label;

    return player.identity || "Media";
}

function percent(value, max) {
    return Math.max(0, Math.min(max, Math.round(value * 100)));
}
