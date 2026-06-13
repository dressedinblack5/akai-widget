function buildModelList(data, recentValues) {
    var allModels = [];
    var list = [];
    var connectedFilter = null;

    if (data && data.all && Array.isArray(data.all)) {
        list = data.all;
        connectedFilter = Array.isArray(data.connected) ? data.connected : null;
    } else if (Array.isArray(data)) {
        list = data;
    } else if (data && data.providers) {
        list = data.providers;
    }

    for (var i = 0; i < list.length; i++) {
        var p = list[i];
        if (!p.id || !p.name || p.enabled === false) continue;
        if (connectedFilter && connectedFilter.indexOf(p.id) === -1) continue;

        var pid = p.id;
        if (p.models) {
            for (var mid in p.models) {
                if (p.models.hasOwnProperty(mid)) {
                    var m = p.models[mid];
                    allModels.push({
                        display: p.name + ": " + (m.name || mid),
                        value: pid + "/" + mid,
                        providerName: p.name,
                        providerId: pid
                    });
                }
            }
        } else {
            allModels.push({display: p.name, value: pid + "/default", providerName: p.name, providerId: pid});
        }
    }

    return sortWithRecent(allModels, recentValues);
}

function buildModelListFromConfig(data, recentValues) {
    var allModels = [];
    var providers = data.providers || {};
    var connectedFilter = Array.isArray(data.connected) ? data.connected : null;

    for (var pid in providers) {
        if (!providers.hasOwnProperty(pid)) continue;
        if (connectedFilter && connectedFilter.indexOf(pid) === -1) continue;
        var p = providers[pid];
        var name = p.name || pid;
        var pModels = p.models || {};
        var modelCount = 0;

        for (var mid in pModels) {
            if (pModels.hasOwnProperty(mid)) {
                var m = pModels[mid];
                allModels.push({
                    display: name + ": " + (m.name || mid),
                    value: pid + "/" + mid,
                    providerName: name,
                    providerId: pid
                });
                modelCount++;
            }
        }

        if (modelCount === 0) {
            allModels.push({display: name + ": default", value: pid + "/default", providerName: name, providerId: pid});
        }
    }

    return sortWithRecent(allModels, recentValues);
}

function sortWithRecent(allModels, recentValues) {
    var recentSet = {};
    if (recentValues && Array.isArray(recentValues)) {
        for (var ri = 0; ri < recentValues.length; ri++)
            recentSet[recentValues[ri]] = true;
    }

    var models = [];
    if (recentValues && recentValues.length > 0) {
        for (var ri = 0; ri < recentValues.length; ri++) {
            var rv = recentValues[ri];
            for (var ai = 0; ai < allModels.length; ai++) {
                if (allModels[ai].value === rv) {
                    models.push({
                        display: allModels[ai].display,
                        value: rv,
                        providerName: "\u2B50 Recent",
                        providerId: allModels[ai].providerId
                    });
                    break;
                }
            }
        }
    }

    var nonRecent = [];
    for (var ai = 0; ai < allModels.length; ai++) {
        if (!recentSet[allModels[ai].value])
            nonRecent.push(allModels[ai]);
    }

    nonRecent.sort(function(a, b) {
        var aZen = a.value.indexOf("opencode/") === 0;
        var bZen = b.value.indexOf("opencode/") === 0;
        if (aZen && !bZen) return -1;
        if (!aZen && bZen) return 1;
        var aGo = a.value.indexOf("opencode-go/") === 0;
        var bGo = b.value.indexOf("opencode-go/") === 0;
        if (aGo && !bGo) return -1;
        if (!aGo && bGo) return 1;
        return 0;
    });

    for (var ni = 0; ni < nonRecent.length; ni++)
        models.push(nonRecent[ni]);

    return models.length > 0 ? models : [{display: "No models found", value: ""}];
}
