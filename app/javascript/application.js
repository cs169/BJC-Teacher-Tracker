import "./styles/application.scss"
import "./styles/actiontext.scss"

import $ from "jquery"
import Rails from "@rails/ujs"
import "jquery-ujs/src/rails"
import "bootstrap"
import "popper.js"
import "@fortawesome/fontawesome-free/js/all"

import tinymce from "tinymce"
import "tinymce/icons/default"
import "tinymce/themes/silver"
import "tinymce/plugins/image"
import "tinymce/plugins/link"
import "tinymce/plugins/paste"
import "tinymce/plugins/table"
import "tinymce/plugins/code"
import "tinymce/skins/ui/oxide/skin.min.css"
import "tinymce/skins/content/default/content.css"
import "tinymce/skins/ui/oxide/content.min.css"

import "datatables.net"
import "datatables.net-bs4"
import "datatables.net-buttons-bs4"
import "datatables.net-buttons/js/buttons.html5.js"

import "./modules/datatables"
import "./modules/schools"

window.$ = window.jQuery = $
window.tinymce = tinymce
Rails.start()

$(function() {
  $('[data-toggle="tooltip"]').tooltip()
})
