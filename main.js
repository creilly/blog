document.addEventListener('DOMContentLoaded', function () {
  var btn = document.getElementById('dm');
  if (localStorage.getItem('dark') === '1') document.body.classList.add('dark');
  initBackLink(btn);
  if (btn) {
    btn.addEventListener('click', function () {
      var on = document.body.classList.toggle('dark');
      localStorage.setItem('dark', on ? '1' : '0');
    });
  }

  initToc();
  initFootnotes();
});

function initToc() {
  if (!document.body.classList.contains('toc')) return;
  if (document.getElementById('generated-toc')) return;

  var h2s = Array.from(document.querySelectorAll('h2')).filter(function (h2) {
    return h2.textContent && h2.textContent.trim();
  });
  if (!h2s.length) return;

  var usedIds = new Set(
    Array.from(document.querySelectorAll('[id]')).map(function (el) {
      return el.id;
    })
  );

  var nav = document.createElement('nav');
  nav.id = 'generated-toc';
  nav.setAttribute('aria-label', 'Table of contents');
  nav.style.margin = '1.25em 0 1.5em';

  var title = document.createElement('div');
  title.textContent = 'Contents';
  title.style.fontWeight = '600';
  title.style.letterSpacing = '0.02em';
  title.style.marginBottom = '0.5em';
  nav.appendChild(title);

  var list = document.createElement('ol');
  list.style.margin = '0';
  list.style.paddingLeft = '1.2em';
  list.style.lineHeight = '1.45';

  h2s.forEach(function (h2) {
    if (!h2.id) {
      h2.id = makeUniqueHeadingId(h2.textContent, usedIds);
      usedIds.add(h2.id);
    }

    var li = document.createElement('li');
    var a = document.createElement('a');
    a.href = '#' + h2.id;
    a.textContent = h2.textContent.trim();

    li.appendChild(a);
    list.appendChild(li);

    addHeadingBackToTocLink(h2);
  });

  nav.appendChild(list);

  var abstract = document.querySelector('div.abstract');
  var h1 = document.querySelector('h1');

  if (abstract && abstract.parentNode) {
    abstract.insertAdjacentElement('afterend', nav);
  } else if (h1 && h1.parentNode) {
    h1.insertAdjacentElement('afterend', nav);
  } else {
    document.body.insertBefore(nav, document.body.firstChild);
  }
}

function makeUniqueHeadingId(text, usedIds) {
  var base = String(text || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-');

  if (!base) base = 'section';
  if (!usedIds.has(base)) return base;

  var i = 2;
  while (usedIds.has(base + '-' + i)) {
    i += 1;
  }
  return base + '-' + i;
}

function addHeadingBackToTocLink(h2) {
  if (!h2 || h2.querySelector('a.toc-back')) return;

  var back = document.createElement('a');
  back.className = 'toc-back';
  back.href = '#generated-toc';
  back.setAttribute('aria-label', 'Back to table of contents');
  back.textContent = ' \u2191\uFE0E';
  back.style.textDecoration = 'none';
  back.style.fontSize = '0.85em';
  back.style.marginLeft = '0.35em';
  back.style.opacity = '0.8';

  h2.appendChild(back);
}

function initBackLink(dmButton) {
  if (document.getElementById('back-home')) return;

  var path = window.location.pathname.toLowerCase();
  if (path === '/' || path.endsWith('/index.php')) return;

  var back = document.createElement('a');
  back.id = 'back-home';
  back.setAttribute('href', 'index.php');
  back.setAttribute('title', 'Back to index');
  back.setAttribute('aria-label', 'Back to index');
  back.textContent = '\u2190\uFE0E';

  if (dmButton && dmButton.parentNode) {
    dmButton.insertAdjacentElement('afterend', back);
    return;
  }

  document.body.appendChild(back);
}

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
  backlink.textContent = '\u21A9\uFE0E';

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
