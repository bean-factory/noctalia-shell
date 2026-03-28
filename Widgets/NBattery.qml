import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Services.UPower

// Battery widget with Android 16 style rendering (horizontal or vertical)
Item {
  id: root

  // Data (must be provided by parent)
  required property real percentage
  required property bool charging
  required property bool pluggedIn
  required property bool ready
  required property bool low
  required property bool critical

  // Sizing - baseSize controls overall scaleFactor for bar/panel usage
  property real baseSize: Style.fontSizeM

  // Styling - no hardcoded colors, only theme colors
  property color baseColor: Color.mOnSurface
  property color lowColor: Color.mError
  property color chargingColor: "#b2dba1"
  property color saverColor: "#fdcc03"
  property color textColor: Color.mSurface

  // Display options
  property bool showPercentageText: true
  property bool vertical: false

  // Internal sizing calculations based on baseSize
  readonly property real scaleFactor: baseSize / Style.fontSizeM
  readonly property real bodyWidth: {
    const min = Style.toOdd(32 * scaleFactor);
    if (!showPercentageText) {
      return min;
    }

    // increase length when showing 100%
    if (percentage > 99) {
      const max = Style.toOdd(30 * scaleFactor);
      return max + 6;
    }
    return min + 6;
  }

  readonly property real bodyHeight: Style.toOdd(18 * scaleFactor)
  readonly property real terminalWidth: Math.round(0 * scaleFactor)
  readonly property real terminalHeight: Math.round(7 * scaleFactor)
  readonly property real cornerRadius: Math.round(0 * scaleFactor)

  // Total size is just body + terminal (no external icon)
  readonly property real totalWidth: vertical ? bodyHeight : bodyWidth + terminalWidth
  readonly property real totalHeight: vertical ? bodyWidth + terminalWidth : bodyHeight

  // Determine active color based on state
  readonly property color activeColor: {
    if (!ready) {
      return Qt.alpha(baseColor, Style.opacityMedium);
    }
    if (charging) {
      return chargingColor;
    }
    if (low || critical) {
      return lowColor;
    }

    return baseColor;
  }

  // Background color for empty portion (semi-transparent)
  readonly property color emptyColor: Qt.alpha(baseColor, 0.6)

  // State icon logic — binding on PowerProfiles.profile ensures leaf reacts to profile changes
  readonly property string stateIcon: {
    if (!ready)
      return "x";
    if (charging)
      return "bolt-filled";
    if (pluggedIn)
      return "plug-filled";
    if (PowerProfiles.profile == PowerProfile.PowerSaver)
      return "seedling-filled";
    if (PowerProfiles.profile == PowerProfile.Performance)
      return "performance";
    return "";
  }
  property string renderedStateIcon: stateIcon
  property real stateIconVisibility: stateIcon !== "" ? 1 : 0

  onStateIconChanged: {
    if (stateIcon !== "") {
      renderedStateIcon = stateIcon;
    }
  }

  // Animated percentage for smooth transitions
  property real animatedPercentage: percentage

  Behavior on animatedPercentage {
    enabled: !Settings.data.general.animationDisabled
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Behavior on stateIconVisibility {
    enabled: !Settings.data.general.animationDisabled
    NumberAnimation {
      duration: Style.animationFast
      easing.type: Easing.InOutQuad
    }
  }

  implicitWidth: Math.round(totalWidth)
  implicitHeight: Math.round(totalHeight)
  Layout.maximumWidth: implicitWidth
  Layout.maximumHeight: implicitHeight

  // Battery body container
  Item {
    id: batteryBody
    width: root.vertical ? root.bodyHeight : root.bodyWidth + root.terminalWidth
    height: root.vertical ? root.bodyWidth + root.terminalWidth : root.bodyHeight
    anchors.left: root.vertical ? undefined : parent.left
    anchors.bottom: root.vertical ? parent.bottom : undefined
    anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
    anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter

    // Battery body background
    Rectangle {
      id: bodyBackground
      y: root.vertical ? root.terminalWidth : 0
      width: root.vertical ? root.bodyHeight : root.bodyWidth
      height: root.vertical ? root.bodyWidth : root.bodyHeight
      radius: root.cornerRadius
      color: root.emptyColor
    }

    // Terminal cap
    Rectangle {
      x: root.vertical ? (root.bodyHeight - root.terminalHeight) / 2 : root.bodyWidth
      y: root.vertical ? 0 : (root.bodyHeight - root.terminalHeight) / 2
      width: root.vertical ? root.terminalHeight : root.terminalWidth
      height: root.vertical ? root.terminalWidth : root.terminalHeight
      radius: root.cornerRadius / 2
      color: root.critical ? root.lowColor : root.emptyColor
    }

    // Fill level
    Rectangle {
      id: fillRect
      visible: root.ready && (root.animatedPercentage > 0 || root.critical)
      x: 0
      y: root.vertical ? root.terminalWidth + root.bodyWidth * (1 - (root.critical ? 1 : root.animatedPercentage / 100)) : 0
      width: root.vertical ? root.bodyHeight : root.bodyWidth * (root.critical ? 1 : Math.min(root.animatedPercentage/90,1))
      height: root.vertical ? root.bodyWidth * (root.critical ? 1 : root.animatedPercentage / 100) : root.bodyHeight
      radius: root.cornerRadius
      color: root.activeColor
    }
  }

  // Icon + percentage text shown side by side, centered in the battery body.
  // Icon is hidden when empty (no stateIcon) so text stays centered alone.
  Row {
    id: contentRow
    spacing: 0
    readonly property real iconGap: 3
    // Centre the row within the visible body rectangle
    x: batteryBody.x + bodyBackground.x + (bodyBackground.width  - width)  / 2
    y: batteryBody.y + bodyBackground.y + (bodyBackground.height - height) / 2

    Behavior on opacity {
      enabled: !Settings.data.general.animationDisabled
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }

    // State icon slot keeps layout stable while icon slides in/out.
    Item {
      id: stateIconSlot
      width: (stateIconItem.implicitWidth + contentRow.iconGap) * root.stateIconVisibility
      height: Math.max(stateIconItem.implicitHeight, percentageText.implicitHeight)
      clip: true

      NIcon {
        id: stateIconItem
        visible: opacity > 0
        opacity: root.stateIconVisibility
        icon: root.renderedStateIcon
        pointSize: Style.toOdd(root.baseSize * 0.85) - 1
        color: Qt.alpha(root.textColor, 1)
        anchors.verticalCenter: parent.verticalCenter
        x: (root.stateIconVisibility - 1) * implicitWidth
      }
    }

    // Percentage text
    NText {
      id: percentageText
      visible: root.showPercentageText && root.ready
      font.family: Settings.data.ui.fontFixed
      font.weight: Style.fontWeightBold
      text: root.vertical
        ? String(Math.round(root.animatedPercentage)).split('').join('\n')
        : Math.round(root.animatedPercentage)
      pointSize: root.baseSize * 0.82
      color: Qt.alpha(root.textColor, 1)
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      lineHeight: root.vertical ? 0.7 : 1.0
      lineHeightMode: Text.ProportionalHeight
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
