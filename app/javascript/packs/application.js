/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb


// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
const images = require.context('../images', true);
// const imagePath = (name) => images(name, true)

import * as $ from 'jquery';
window.$ = $;
import 'jquery-ujs/src/rails';
import 'bootstrap';
import 'popper.js';
import "@fortawesome/fontawesome-free/js/all";

import Rails from '@rails/ujs';
Rails.start();

// TODO: These really out to be an 'admin' pack.
// Import TinyMCE
import 'tinymce';

// Default icons are required for TinyMCE 5.3 or above
import 'tinymce/icons/default';

import 'tinymce/themes/silver';
// Any plugins you want to use has to be imported
import 'tinymce/plugins/image';
import 'tinymce/plugins/link';
import 'tinymce/plugins/paste';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';

// TinyMCE Skins. These need to be manually loaded.
import 'tinymce/skins/ui/oxide/skin.min.css';
import 'tinymce/skins/content/default/content.css';
import 'tinymce/skins/ui/oxide/content.min.css';

import 'datatables.net';
import "datatables.net-bs4";
import "datatables.net-buttons-bs4";
import 'datatables.net-buttons/js/buttons.html5.js';

import './datatables.js';
import './schools_index.js';
import '../styles/application.scss';
import './schools.js';

$(function () {
  $('[data-toggle="tooltip"]').tooltip()
});
