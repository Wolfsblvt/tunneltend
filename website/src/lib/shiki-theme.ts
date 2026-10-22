// SPDX-License-Identifier: AGPL-3.0-only
/**
 * The Moonpool syntax palette as a Shiki theme: a few restrained classes on the graphite
 * machine ground, identical in both site themes because code always sits on that ground.
 */
import type { ThemeRegistrationRaw } from 'shiki';

const ground = '#121118', text = '#f0edf3', muted = '#aaa4b2', punct = '#7d7686', comment = '#6f6878';
const cyan = '#79cad9', chalk = '#e7e1ec', amber = '#e4b368', green = '#6bbc96', rose = '#f08a97';

export const moonpoolSyntax: ThemeRegistrationRaw = {
  name: 'moonpool',
  type: 'dark',
  colors: { 'editor.background': ground, 'editor.foreground': text },
  settings: [
    { settings: { foreground: text, background: ground } },
    { scope: ['comment', 'punctuation.definition.comment'], settings: { foreground: comment, fontStyle: 'italic' } },
    { scope: ['string', 'string.quoted', 'string.unquoted', 'punctuation.definition.string'], settings: { foreground: chalk } },
    { scope: ['constant.numeric', 'constant.language', 'constant.language.boolean', 'constant.language.null'], settings: { foreground: amber } },
    { scope: ['entity.name.tag', 'support.type.property-name', 'meta.object-literal.key', 'variable.other.property', 'entity.other.attribute-name'], settings: { foreground: cyan } },
    { scope: ['punctuation', 'punctuation.separator', 'punctuation.definition', 'meta.brace', 'keyword.operator'], settings: { foreground: punct } },
    { scope: ['keyword', 'storage', 'storage.type', 'keyword.control'], settings: { foreground: cyan } },
    { scope: ['entity.name.function', 'support.function'], settings: { foreground: text } },
    { scope: ['variable', 'variable.parameter', 'variable.other'], settings: { foreground: muted } },
    { scope: ['markup.inserted'], settings: { foreground: green } },
    { scope: ['markup.deleted'], settings: { foreground: rose } },
  ],
};
