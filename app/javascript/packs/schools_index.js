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
    buttons: ['copy', 'csv'],
    language: {
      search: '_INPUT_',
      searchPlaceholder: 'Search'
    },
    autoWidth: false
  });
}

$(document).ready(initSchoolsTable);
$(document).on('turbolinks:load', initSchoolsTable);
