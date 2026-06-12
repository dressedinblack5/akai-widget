import QtQuick

Canvas {
    id: root

    property var values: []
    property real minValue: 0
    property real maxValue: 100
    property bool autoScale: true
    property bool showFill: true
    property bool showLine: true
    property color lineColor: "#3a7bd5"
    property color fillColor: "#1a3a7bd5"
    property real lineWidth: 1.5
    property real _computedMax: autoScale ? Math.max.apply(null, root.values.length > 0 ? root.values : [1]) : root.maxValue
    property real _computedMin: autoScale ? Math.min.apply(null, root.values.length > 0 ? root.values : [0]) : root.minValue
    property real _range: _computedMax === _computedMin ? 1 : _computedMax - _computedMin

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onFillColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        var cw = width;
        var ch = height;
        var len = root.values.length;

        ctx.clearRect(0, 0, cw, ch);

        if (len < 2) return;

        var pad = 1;
        var drawW = cw - pad * 2;
        var drawH = ch - pad * 2;

        var points = [];
        for (var i = 0; i < len; i++) {
            var x = pad + (i / (len - 1)) * drawW;
            var y = pad + drawH - ((root.values[i] - root._computedMin) / root._range) * drawH;
            points.push({x: x, y: y});
        }

        if (root.showFill) {
            ctx.beginPath();
            ctx.moveTo(points[0].x, ch - pad);
            for (var i = 0; i < points.length; i++) {
                ctx.lineTo(points[i].x, points[i].y);
            }
            ctx.lineTo(points[points.length - 1].x, ch - pad);
            ctx.closePath();
            ctx.fillStyle = root.fillColor;
            ctx.fill();
        }

        if (root.showLine) {
            ctx.beginPath();
            ctx.moveTo(points[0].x, points[0].y);
            for (var i = 1; i < points.length; i++) {
                ctx.lineTo(points[i].x, points[i].y);
            }
            ctx.strokeStyle = root.lineColor;
            ctx.lineWidth = root.lineWidth;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();
        }
    }
}
