import $ from "jquery"

export function initDataTables() {
  $(function() {
  // Filtering for the Admin Teachers Index
  $.fn.dataTable.ext.search.push((_, searchData) => {
    let enabled = $('input:checkbox[name="statusFilter"]:checked').map((_i, el) => el.value).get();
    // Include all rows when no checkboxes are selected.
    return enabled.length === 0 || enabled.includes(searchData[5]);
  });

  let $tables = $('.js-dataTable').DataTable({
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
  });

  $tables.draw();
  $(".custom-checkbox").on("change", () => {
      $tables.draw();
  });
  $tables.on('draw', function() {
      $('[data-toggle="tooltip"]').tooltip('dispose');
      $('[data-toggle="tooltip"]').tooltip();
  });

  // Cross-filter search notice: after the user stops typing for 300ms, query
  // the server for result counts per status and surface any that are hidden
  // by the current checkbox filter.
  let crossFilterTimer;
  let currentRequest = null;

  function scheduleCrossFilterUpdate() {
    clearTimeout(crossFilterTimer);

    crossFilterTimer = setTimeout(function() {
      const checked = $('input:checkbox[name="statusFilter"]:checked').map((_, el) => el.value).get();
      const query = $tables.table('.js-teachersTable').search();

      if (!query.trim() || checked.length === 0) {
        $('#cross-filter-notice').text('');
        return;
      }

      if (currentRequest) { currentRequest.abort(); }

      currentRequest = $.get('/teachers/cross_filter_search', { q: query }, function(data) {
        const messages = [];
        $.each(data, function(status, count) {
          if (!checked.includes(status)) {
            messages.push(`${count} result(s) in ${status}`);
          }
        });
        const notice = messages.length > 0 ? messages.join(', ') + ' \u2014 hidden by current filter' : '';
        $('#cross-filter-notice').text(notice);
      }).always(function() {
        currentRequest = null;
      }).fail(function(xhr) {
        if (xhr.statusText !== 'abort') { $('#cross-filter-notice').text(''); }
      });
    }, 300);
  }

  $tables.on('search.dt', scheduleCrossFilterUpdate);
  $('.custom-checkbox').on('change', scheduleCrossFilterUpdate);
  });
}

initDataTables();

export default initDataTables;
