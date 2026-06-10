// Pure utility functions for the AI Chat widget

function extractReply(data) {
    if (data.text) return data.text
    if (data.content) return typeof data.content === "string" ? data.content : JSON.stringify(data.content)
    if (data.message) return typeof data.message === "string" ? data.message : JSON.stringify(data.message)
    if (data.parts) {
        var text = ""
        for (var i = 0; i < data.parts.length; i++) {
            if (data.parts[i].type === "text") text += data.parts[i].text
        }
        return text
    }
    if (data.tokens) return data.tokens
    return JSON.stringify(data)
}

function buildModelList(data) {
    var models = []
    var list = []
    var connectedFilter = null

    if (data && data.all && Array.isArray(data.all)) {
        list = data.all
        connectedFilter = Array.isArray(data.connected) ? data.connected : null
    } else if (Array.isArray(data)) {
        list = data
    } else if (data && data.providers) {
        list = data.providers
    }

    for (var i = 0; i < list.length; i++) {
        var p = list[i]
        if (!p.id || !p.name || p.enabled === false) continue
        if (connectedFilter && connectedFilter.indexOf(p.id) === -1) continue

        var pid = p.id
        if (p.models) {
            for (var mid in p.models) {
                if (p.models.hasOwnProperty(mid)) {
                    var m = p.models[mid]
                    models.push({
                        display: p.name + ": " + (m.name || mid),
                        value: pid + "/" + mid
                    })
                }
            }
        } else {
            models.push({ display: p.name, value: pid + "/default" })
        }
    }
    return models.length > 0 ? models : [{ display: "No models found", value: "" }]
}

function buildModelListFromConfig(data) {
    var models = []
    var providers = data.providers || {}
    for (var pid in providers) {
        if (!providers.hasOwnProperty(pid)) continue
        var p = providers[pid]
        var name = p.name || pid
        var pModels = p.models || {}
        for (var mid in pModels) {
            if (pModels.hasOwnProperty(mid)) {
                var m = pModels[mid]
                models.push({
                    display: name + ": " + (m.name || mid),
                    value: pid + "/" + mid
                })
            }
        }
        if (Object.keys(pModels).length === 0) {
            models.push({ display: name + ": default", value: pid + "/default" })
        }
    }
    return models.length > 0 ? models : [{ display: "No models found", value: "" }]
}

function addMessage(role, text, messages) {
    var now = new Date()
    var h = now.getHours().toString().padStart(2, '0')
    var m = now.getMinutes().toString().padStart(2, '0')
    var msg = { role: role, text: text, time: h + ":" + m }
    return messages.slice().concat([msg])
}

function formatTime(date) {
    var h = date.getHours().toString().padStart(2, '0')
    var m = date.getMinutes().toString().padStart(2, '0')
    return h + ":" + m
}
