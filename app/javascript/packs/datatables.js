$(function() {
  // Filtering for the Admin Teachers Index
  $.fn.dataTable.ext.search.push((_, searchData) => {
    let enabled = $('input:checkbox[name="statusFilter"]:checked').map((_i, el) => el.value).get();
    return enabled.length === 0 || enabled.includes(searchData[5]);
  });

  const sharedConfig = {
    dom:
      `<'row form-row'<'col-6 form-inline'i><'col-6 form-inline'lf>>
      <'row'<'col-12'tr>>
      <'row'<'col-sm-12 col-md-5'B><'col-sm-12 col-md-4'p>>`,
    pageLength: 100,
    lengthMenu: [ [25, 50, 100, 250, -1], [25, 50, 100, 250, "All"] ],
    buttons: [ 'copy', 'csv' ],
    language: {
      search: '_INPUT_',
      searchPlaceholder: 'Search'
    },
    autoWidth: false,
  };

  // Teachers table (client-side)
  let $tables = $('.js-dataTable').DataTable(sharedConfig);

  // Schools table (server-side)
  $('.js-schoolDataTable').DataTable({
    ...sharedConfig,
    serverSide: true,
    ajax: '/schools.json',
    columns: [
      { data: 'name' },
      { data: 'location' },
      { data: 'country' },
      { data: 'website' },
      { data: 'teachers_count' },
      { data: 'grade_level' },
      { data: 'actions', orderable: false, searchable: false }
    ]
  });

  $tables.draw();
  $(".custom-checkbox").on("change", () => {
      $tables.draw();
  });
  $tables.on('draw', function() {
      $('[data-toggle="tooltip"]').tooltip('dispose');
      $('[data-toggle="tooltip"]').tooltip();
  });
});
