// Samsung (Tizen): the HDMI picture is a TV window behind the page.
// Samsung's own API, present on the TV only. Needed before the page's script runs.
document.write('<script src="$WEBAPIS/webapis/webapis.js"><\/script>');
window.TVPlatform = {
  name: 'Samsung TV',
  start: function () {
    try {
      for (var i = 0; i < 10; i++) { tizen.tvinputdevice.registerKey(String(i)); }
    } catch (e) { /* Remotes without digits use the keys on screen. */ }
    // Otherwise the screen saver covers a game that gets no remote input.
    try { webapis.appcommon.setScreenSaver(webapis.appcommon.AppCommonScreenSaverState.SCREEN_SAVER_OFF); } catch (e) {}
  },
  inputs: function (done) {
    try {
      tizen.systeminfo.getPropertyValue('VIDEOSOURCE', function (sources) {
        var found = [], connected = sources.connected || [];
        for (var i = 0; i < connected.length; i++) {
          if (connected[i].type !== 'HDMI') { continue; }
          found.push({ id: 'HDMI' + connected[i].number, label: 'HDMI ' + connected[i].number, source: connected[i] });
        }
        done(found);
      }, function () { done([]); });
    } catch (e) { done([]); }
  },
  showInput: function (input, success, failure) {
    try {
      tizen.tvwindow.setSource(input.source, function () {
        tizen.tvwindow.show(success, failure, ['0px', '0px', '1920px', '1080px'], 'MAIN', 'BEHIND');
      }, failure, 'MAIN');
    } catch (e) { failure(e); }
  },
  hideInput: function () {
    try { tizen.tvwindow.hide(function () {}, function () {}, 'MAIN'); } catch (e) {}
  },
  exit: function () { tizen.application.getCurrentApplication().exit(); }
};
