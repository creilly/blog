document.addEventListener('DOMContentLoaded', function () {
  var btn = document.getElementById('dm');
  if (localStorage.getItem('dark') === '1') document.body.classList.add('dark');
  if (btn) {
    btn.addEventListener('click', function () {
      var on = document.body.classList.toggle('dark');
      localStorage.setItem('dark', on ? '1' : '0');
    });
  }

  initFootnotes();
});

function initFootnotes() {
  var refSection = document.querySelector('section.ref');
  if (!refSection) return;

  // All in-text footnote citations should use class="fn".
  var fnLinks = Array.from(document.querySelectorAll('a.fn'));

  // We keep order by first citation appearance and map that to a single note.
  var orderedKeys = [];
  var noteByKey = new Map();
  var primaryByKey = new Map();

  fnLinks.forEach(function (link) {
    var key = getFootnoteKey(link);
    if (!key) return;

    // Store canonical key for secondary references that use data-fn.
    link.setAttribute('data-fn', key);

    // First citation for a key is the backlink target.
    if (!primaryByKey.has(key)) {
      primaryByKey.set(key, link);
    }

    // Authoring-time markup can omit href; derive it from the ref key.
    link.setAttribute('href', '#fn' + key);

    var note = document.getElementById('fn' + key);
    if (!note || !refSection.contains(note)) return;

    if (!noteByKey.has(key)) {
      noteByKey.set(key, note);
      orderedKeys.push(key);
    }
  });

  // Build note list in citation order and assign visible note indices.
  var indexByKey = new Map();
  orderedKeys.forEach(function (key, i) {
    var note = noteByKey.get(key);
    var primary = primaryByKey.get(key);
    var primaryId = ensurePrimaryRefId(primary, key);

    note.insertAdjacentText('afterbegin', (i + 1) + '. ');
    setBacklink(note, primaryId);
    refSection.appendChild(note);

    indexByKey.set(key, i + 1);
  });

  // Render each citation as n (or [n] for nosup).
  fnLinks.forEach(function (link) {
    var key = getFootnoteKey(link);
    if (!indexByKey.has(key)) return;
    applyCitationDisplay(link, indexByKey.get(key));
  });
}

function getFootnoteKey(link) {
  // Preferred authoring: data-fn="key" for repeat citations.
  var fromData = (link.getAttribute('data-fn') || '').trim();
  if (fromData) return fromData;

  // Primary citation can be authored as id="ref{key}".
  if (link.id && link.id.indexOf('ref') === 0) {
    return link.id.slice(3);
  }

  return '';
}

function ensurePrimaryRefId(link, key) {
  // Backlinks need an anchor target; ensure the primary citation has one.
  if (!link) return 'ref' + key;
  if (!link.id) {
    link.id = 'ref' + key;
  }
  return link.id;
}

function setBacklink(p, targetId) {
  // Append a backlink arrow at the end of the note paragraph.
  var backlink = document.createElement('a');
  backlink.setAttribute('href', '#' + targetId);
  backlink.textContent = '↩';

  p.appendChild(document.createTextNode(' '));
  p.appendChild(backlink);
}

function applyCitationDisplay(link, n) {
  var hasNoSup = link.hasAttribute('nosup');

  if (hasNoSup) {
    // Inline style citation for prose references.
    link.textContent = '[' + n + ']';
    return;
  }

  // Default citation style is superscript number.
  link.textContent = String(n);
  if (link.parentElement && link.parentElement.tagName === 'SUP') return;

  var sup = document.createElement('sup');
  var parent = link.parentNode;
  if (!parent) return;
  parent.insertBefore(sup, link);
  sup.appendChild(link);
}
