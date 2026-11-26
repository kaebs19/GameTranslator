// LG (webOS): the HDMI picture is a <video> with an undocumented source type.
// LG may refuse it on some models; the page then offers text only.
(function () {
  var TIMEOUT = 6000;
  var video = null;

  function hide() {
    if (!video) { return; }
    video.pause();
    video.textContent = '';
    video.load();
    video.parentNode.removeChild(video);
    video = null;
  }

  window.TVPlatform = {
    name: 'LG TV',
    start: function () {},
    inputs: function (done) {
      var all = [];
      // There is no public way to ask which ones are in use.
      for (var i = 1; i <= 4; i++) { all.push({ id: 'HDMI' + i, label: 'HDMI ' + i, number: i }); }
      done(all);
    },
    showInput: function (input, success, failure) {
      hide();
      var element = document.createElement('video'), source = document.createElement('source');
      var isDone = false;
      function finish(isShown) {
        if (isDone) { return; }
        isDone = true;
        if (isShown) { success(); } else { hide(); failure(); }
      }
      video = element;
      element.autoplay = true;
      element.style.cssText = 'position:absolute;left:0;top:0;width:100%;height:100%';
      source.type = 'service/webos-external';
      source.src = 'ext://hdmi:' + input.number;
      element.addEventListener('playing', function () { finish(true); });
      element.addEventListener('loadedmetadata', function () { finish(true); });
      element.addEventListener('error', function () { finish(false); });
      source.addEventListener('error', function () { finish(false); });
      element.appendChild(source);
      document.getElementById('input').appendChild(element);
      setTimeout(function () { finish(false); }, TIMEOUT);
    },
    hideInput: hide,
    exit: function () { window.close(); }
  };
})();
