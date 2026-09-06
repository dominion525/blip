// Copy buttons and the release list. Both pages load this file.

document.querySelectorAll(".copy").forEach(function (button) {
  var source = document.querySelector(button.dataset.copy);
  var label = button.textContent.trim();
  button.textContent = label;
  button.addEventListener("click", function () {
    navigator.clipboard.writeText(source.textContent.trim()).then(
      function () {
        button.textContent = button.dataset.copied;
        setTimeout(function () {
          button.textContent = label;
        }, 1600);
      },
      function () {
        // Clipboard access can be refused. Leave the command on screen to select by hand.
      },
    );
  });
});

// The release workflow appends an item to the appcast on every release, so the list below
// stays current without this page being edited. It only appears once the feed has been read.
var list = document.querySelector("[data-releases]");

if (list) {
  var sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle";
  var limit = Number(list.dataset.releases) || 5;
  var locale = document.documentElement.lang || "en";

  fetch("/appcast.xml")
    .then(function (response) {
      if (!response.ok) throw new Error(response.status);
      return response.text();
    })
    .then(function (text) {
      var feed = new DOMParser().parseFromString(text, "application/xml");
      if (feed.querySelector("parsererror")) throw new Error("malformed feed");

      var items = Array.prototype.slice.call(
        feed.querySelectorAll("item"),
        0,
        limit,
      );
      var rows = items
        .map(function (item) {
          var enclosure = item.querySelector("enclosure");
          var version =
            (enclosure &&
              enclosure.getAttributeNS(sparkle, "shortVersionString")) ||
            (item.querySelector("title") || {}).textContent;
          var notes = item.getElementsByTagNameNS(
            sparkle,
            "releaseNotesLink",
          )[0];
          var published = item.querySelector("pubDate");
          if (!version) return null;

          var row = document.createElement("li");

          var name = document.createElement("span");
          name.className = "release-version";
          name.textContent = version.trim();

          if (notes && notes.textContent.trim()) {
            var link = document.createElement("a");
            link.href = notes.textContent.trim();
            link.appendChild(name);
            row.appendChild(link);
          } else {
            row.appendChild(name);
          }

          var when = published && new Date(published.textContent);
          if (when && !isNaN(when)) {
            var time = document.createElement("time");
            time.dateTime = when.toISOString().slice(0, 10);
            time.textContent = new Intl.DateTimeFormat(locale, {
              year: "numeric",
              month: "long",
              day: "numeric",
            }).format(when);
            row.appendChild(time);
          }

          return row;
        })
        .filter(Boolean);

      if (!rows.length) return;
      rows.forEach(function (row) {
        list.appendChild(row);
      });
      list.hidden = false;
    })
    .catch(function () {
      // The feed did not load. The link to the releases on GitHub stays as the way in.
    });
}
