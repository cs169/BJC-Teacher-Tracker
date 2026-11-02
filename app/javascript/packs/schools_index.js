function initSchoolsTable() {
  var $table = $('#schools-table');
  if (!$table.length || $.fn.DataTable.isDataTable($table)) return;

  $table.DataTable({
    serverSide: true,
    processing: true,
    ajax: $table.data('source'),
    pageLength: 100,
    lengthMenu: [[25, 50, 100, 250], [25, 50, 100, 250]],
    columns: [
      { data: 'name' },
      { data: 'location' },
      { data: 'country' },
      { data: 'website' },
      { data: 'teachers_count', searchable: false },
      { data: 'grade_level', searchable: false },
      { data: 'actions', orderable: false, searchable: false }
    ],
    dom:
      "<'row form-row'<'col-6 form-inline'i><'col-6 form-inline'lf>>" +
      "<'row'<'col-12'tr>>" +
      "<'row'<'col-sm-12 col-md-5'B><'col-sm-12 col-md-4'p>>",
    // Server-side processing only has the current page client-side, so these
    // buttons export just that page. "Export All (CSV)" above the table
    // downloads every school.
    buttons: [
      { extend: 'copy', text: 'Copy Page' },
      { extend: 'csv', text: 'CSV (This Page)' }
    ],
    language: {
      search: '_INPUT_',
      searchPlaceholder: 'Search'
    },
    autoWidth: false
  });
}

$(document).ready(initSchoolsTable);
$(document).on('turbolinks:load', initSchoolsTable);
