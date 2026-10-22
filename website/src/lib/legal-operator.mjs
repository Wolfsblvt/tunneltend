import fixture from '../data/legal-operator.example.json' with { type: 'json' };

export function loadLegalOperator({ requireProduction = false } = {}) {
  const encoded = process.env.WOLFSBLVT_LEGAL_OPERATOR_B64;
  if (!encoded) {
    if (requireProduction) throw new Error('WOLFSBLVT_LEGAL_OPERATOR_B64 is required for publication.');
    return fixture;
  }
  let operator;
  try {
    operator = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
  } catch {
    // JSON parser diagnostics can contain fragments of the private payload.
    throw new Error('WOLFSBLVT_LEGAL_OPERATOR_B64 is not valid base64-encoded JSON.');
  }
  validateOperator(operator);
  if (requireProduction && (operator.fixture === true || containsFixtureValue(operator))) {
    throw new Error('Publication refuses fixture or placeholder legal-operator data.');
  }
  return operator;
}

export function legalContacts(operator, productContact) {
  if (!productContact) return operator.contacts;
  if (
    typeof productContact !== 'object'
    || typeof productContact.address !== 'string'
    || !productContact.address.includes('@')
    || productContact.standing !== 'provisioned'
  ) throw new Error('Product legal contact override requires an email address and standing: provisioned.');
  return { legal: productContact.address, impressum: productContact.address, privacy: productContact.address };
}

export function resolveAdditionalDirectContact(operator, productDirectContact) {
  const contact = productDirectContact ?? operator.additionalDirectContact;
  if (!contact || typeof contact !== 'object') {
    throw new Error('Publication requires a provisioned shared or product-specific additional direct contact pointer.');
  }
  if (typeof contact.label !== 'string' || !contact.label.trim()) {
    throw new Error('Additional direct contact requires a non-empty label.');
  }
  if (typeof contact.href !== 'string' || !isContactFormHref(contact.href)) {
    throw new Error('Additional direct contact requires an absolute HTTPS or site-relative form URL.');
  }
  if (contact.standing !== 'provisioned') {
    throw new Error('Additional direct contact requires standing: provisioned.');
  }
  return contact;
}

export function assertPublicationLegalContact(operator, productContact, productDirectContact) {
  if (operator.fixture === true || containsFixtureValue(operator)) {
    throw new Error('Publication refuses fixture or placeholder legal-operator data.');
  }
  if (operator.contactStanding === 'adopted-unperformed' && !productContact) {
    throw new Error('Publication refuses adopted-unperformed canonical contacts without a provisioned product legal contact.');
  }
  legalContacts(operator, productContact);
  resolveAdditionalDirectContact(operator, productDirectContact);
}

function isContactFormHref(value) {
  if (value.startsWith('/') && !value.startsWith('//')) return true;
  try { return new URL(value).protocol === 'https:'; }
  catch { return false; }
}

function validateOperator(operator) {
  if (!operator || operator.schemaVersion !== 1) throw new Error('Legal operator schemaVersion must be 1.');
  const required = [
    ['operatorId', operator.operatorId],
    ['publisherName', operator.publisherName],
    ['legalName', operator.legalName],
    ['postalAddress.streetAddress', operator.postalAddress?.streetAddress],
    ['postalAddress.postalCode', operator.postalAddress?.postalCode],
    ['postalAddress.locality', operator.postalAddress?.locality],
    ['postalAddress.countryName', operator.postalAddress?.countryName],
    ['contacts.legal', operator.contacts?.legal],
    ['contacts.impressum', operator.contacts?.impressum],
    ['contacts.privacy', operator.contacts?.privacy]
  ];
  for (const [name, value] of required) {
    if (typeof value !== 'string' || !value.trim()) throw new Error('Legal operator requires ' + name + '.');
  }
}

function containsFixtureValue(value) {
  const fixtureSentinels = new Set([
    fixture.operatorId,
    fixture.legalName,
    fixture.postalAddress.streetAddress,
    fixture.postalAddress.postalCode,
    fixture.postalAddress.locality,
    fixture.contacts.legal,
    fixture.contacts.impressum,
    fixture.contacts.privacy,
    fixture.additionalDirectContact.label,
    fixture.additionalDirectContact.href,
    fixture.lastReviewedOn
  ]);
  return Object.values(value).some((entry) => typeof entry === 'string' && (fixtureSentinels.has(entry) || entry.includes('REPLACE_WITH_')))
    || Object.values(value).some((entry) => entry && typeof entry === 'object' && containsFixtureValue(entry));
}
