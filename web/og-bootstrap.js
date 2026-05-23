/**
 * Dynamic Open Graph tags for /a/:agentId (slug or Firebase UID).
 * Runs before Flutter loads so WhatsApp/Facebook crawlers see agent metadata.
 */
(function () {
  var PROJECT_ID = 'hitlook-app';
  var BASE = 'https://hitlook-app.web.app';
  var DEFAULT_IMAGE = BASE + '/icons/og-image.png';
  var DEFAULT_DESC =
    'Descubra seu nível de proteção familiar em menos de 2 minutos.';
  var BRAND_SUFFIX = 'M4LIFE USA';

  var match = window.location.pathname.match(/^\/a\/([^/]+)\/?$/);
  if (!match) return;

  var agentId = decodeURIComponent(match[1]);
  var db = 'https://firestore.googleapis.com/v1/projects/' +
    PROJECT_ID + '/databases/(default)/documents';

  function setMeta(attr, key, value) {
    if (!value) return;
    var el = document.querySelector('meta[' + attr + '="' + key + '"]');
    if (!el) {
      el = document.createElement('meta');
      el.setAttribute(attr, key);
      document.head.appendChild(el);
    }
    el.setAttribute('content', value);
  }

  function resolveImage(photoUrl) {
    if (!photoUrl) return DEFAULT_IMAGE;
    if (photoUrl.indexOf('http://') === 0 || photoUrl.indexOf('https://') === 0) {
      return photoUrl;
    }
    return DEFAULT_IMAGE;
  }

  function applyOg(name, photoUrl) {
    var title = name
      ? name + ' — ' + BRAND_SUFFIX
      : BRAND_SUFFIX + ' — Proteção Familiar';
    var desc = DEFAULT_DESC;
    var image = resolveImage(photoUrl);
    var url = BASE + '/a/' + encodeURIComponent(agentId);

    document.title = title;
    setMeta('name', 'description', desc);
    setMeta('property', 'og:site_name', 'HitLook');
    setMeta('property', 'og:title', title);
    setMeta('property', 'og:description', desc);
    setMeta('property', 'og:image', image);
    setMeta('property', 'og:image:secure_url', image.indexOf('https://') === 0 ? image : DEFAULT_IMAGE);
    setMeta('property', 'og:image:type', image === DEFAULT_IMAGE ? 'image/png' : '');
    setMeta('property', 'og:image:width', image === DEFAULT_IMAGE ? '1200' : '');
    setMeta('property', 'og:image:height', image === DEFAULT_IMAGE ? '630' : '');
    setMeta('property', 'og:url', url);
    setMeta('property', 'og:type', 'website');
    setMeta('name', 'twitter:card', 'summary_large_image');
    setMeta('name', 'twitter:title', title);
    setMeta('name', 'twitter:description', desc);
    setMeta('name', 'twitter:image', image);
  }

  function fieldStr(fields, key) {
    var f = fields && fields[key];
    return f && f.stringValue ? f.stringValue : '';
  }

  function fetchJson(url) {
    return fetch(url).then(function (r) {
      if (!r.ok) throw new Error('http ' + r.status);
      return r.json();
    });
  }

  function loadAgentDoc(id) {
    return fetchJson(db + '/agents/' + encodeURIComponent(id)).then(function (doc) {
      return {
        name: fieldStr(doc.fields, 'nome') || fieldStr(doc.fields, 'displayName'),
        photo: fieldStr(doc.fields, 'fotoUrl') || fieldStr(doc.fields, 'photoUrl'),
        userId: fieldStr(doc.fields, 'userId'),
      };
    });
  }

  function loadSeller(companyId, sellerId) {
    return fetchJson(
      db + '/companies/' + encodeURIComponent(companyId) +
        '/sellers/' + encodeURIComponent(sellerId)
    ).then(function (doc) {
      return {
        name: fieldStr(doc.fields, 'displayName'),
        photo: fieldStr(doc.fields, 'photoUrl'),
        userId: fieldStr(doc.fields, 'userId'),
      };
    });
  }

  function loadViaSlug(slug) {
    return fetchJson(db + '/seller_slugs/' + encodeURIComponent(slug))
      .then(function (slugDoc) {
        var companyId = fieldStr(slugDoc.fields, 'companyId');
        var sellerId = fieldStr(slugDoc.fields, 'sellerId');
        if (!companyId || !sellerId) throw new Error('invalid slug');
        return loadSeller(companyId, sellerId).then(function (seller) {
          return loadAgentDoc(slug).catch(function () { return {}; }).then(function (mirror) {
            return {
              name: seller.name || mirror.name,
              photo: seller.photo || mirror.photo,
              userId: seller.userId || mirror.userId,
            };
          });
        });
      });
  }

  function loadViaUid(uid) {
    return fetchJson(db + '/users/' + encodeURIComponent(uid))
      .then(function (userDoc) {
        var companyId = fieldStr(userDoc.fields, 'companyId');
        var sellerId = fieldStr(userDoc.fields, 'sellerId');
        var chain = Promise.resolve({ name: '', photo: '', userId: uid });
        if (companyId && sellerId) {
          chain = loadSeller(companyId, sellerId);
        }
        return chain.then(function (seller) {
          return loadAgentDoc(uid).catch(function () { return {}; }).then(function (legacy) {
            return {
              name: seller.name || legacy.name || fieldStr(userDoc.fields, 'displayName'),
              photo: seller.photo || legacy.photo,
              userId: uid,
            };
          });
        });
      })
      .catch(function () {
        return loadAgentDoc(uid);
      });
  }

  function looksLikeUid(id) {
    return id.length >= 20 && /^[A-Za-z0-9]+$/.test(id);
  }

  var loader = looksLikeUid(agentId)
    ? loadViaUid(agentId)
    : loadViaSlug(agentId).catch(function () {
        return loadAgentDoc(agentId);
      });

  loader
    .then(function (data) {
      applyOg(data.name, data.photo);
    })
    .catch(function () {
      applyOg('', '');
    });
})();
