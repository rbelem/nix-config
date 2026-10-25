import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  // NixOS deviation from upstream: nothing seeds /var/lib/sddm/state.conf,
  // so lastUser is "" on a fresh system and the greeter would log in as
  // nobody. Fall back to the first user in the model.
  property string currentUser: userModel.lastUser || userModel.data(userModel.index(0, 0), Qt.UserRole + 1) || ""
  property bool loginFailed: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  // SDDM resolves the avatar itself, from FacesDir or the home directory, and
  // hands it over as the icon role: UserRole + 4, after name, realName and
  // homeDir. The role is set even when no file exists, so a missing avatar
  // arrives as a failed decode rather than an empty source.
  property string faceSource: {
    for (var i = 0; i < userModel.rowCount(); i++) {
      var index = userModel.index(i, 0)
      if ((userModel.data(index, Qt.UserRole + 1) || "") === root.currentUser)
        return userModel.data(index, Qt.UserRole + 4) || ""
    }
    return ""
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Image {
      id: logo
      source: "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Item {
      // The face is the theme's logo.png, so the slot takes the logo's shape
      // and reserves that space before the avatar loads. A missing face then
      // leaves an empty slot, not a moved password row.
      width: Math.round(Math.min(root.width * 0.15, 160))
      height: logo.sourceSize.width > 0 ? Math.round(width * logo.sourceSize.height / logo.sourceSize.width) : 0
      anchors.horizontalCenter: parent.horizontalCenter

      Image {
        source: root.faceSource
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: status === Image.Ready
        asynchronous: true
        smooth: true
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "\u2022"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            }
          }
        }
      }
    }

  }

  Component.onCompleted: password.forceActiveFocus()
}
