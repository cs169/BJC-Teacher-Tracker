function countHiddenResults(table, statusColIdx, searchQuery, statusValue) {
  if (!searchQuery) return 0;
  const terms = searchQuery.toLowerCase().trim().split(/\s+/).filter(Boolean);
  const courseFilter = $('#courseFilter').val();
  let count = 0;
  table.rows().every(function() {
    const cache = this.cache('search');
    if (cache[statusColIdx] !== statusValue) return;
    if (courseFilter) {
      const course = $(this.node()).find('td[data-col="course"]').data('course');
      if (course !== courseFilter) return;
    }
    const rowText = cache.join(' ').toLowerCase();
    if (terms.every(term => rowText.includes(term))) count++;
  });
  return count;
}

function updateHiddenResultsNotice(table, statusColIdx) {
  const searchQuery = table.search().trim();
  const $notice = $('#hidden-filter-notice');
  const $allBoxes = $('input:checkbox[name="statusFilter"]');
  const checkedCount = $allBoxes.filter(':checked').length;

  if (!searchQuery || checkedCount === 0 || checkedCount === $allBoxes.length) {
    $notice.text('');
    return;
  }

  const parts = [];
  $allBoxes.not(':checked').each(function() {
    const label = $('label[for="' + this.id + '"]').text().trim();
    const count = countHiddenResults(table, statusColIdx, searchQuery, this.value);
    if (count > 0) parts.push(count + ' result(s) in ' + label);
  });

  $notice.text(parts.length > 0 ? parts.join(', ') + ' — hidden by current filter' : '');
}

$(function() {
  // Filtering for the Admin Teachers Index
  $.fn.dataTable.ext.search.push((_, searchData) => {
    let enabled = $('input:checkbox[name="statusFilter"]:checked').map((_i, el) => el.value).get();
    // Include all rows when no checkboxes are selected.
    return enabled.length === 0 || enabled.includes(searchData[5]);
  });

  // Course filter — only applied to the teachers table, not the admin table
  $.fn.dataTable.ext.search.push((settings, _data, dataIndex) => {
    if (!$(settings.nTable).hasClass('js-teachersTable')) return true;
    const courseFilter = $('#courseFilter').val();
    if (!courseFilter) return true;
    const row = settings.aoData[dataIndex].nTr;
    if (!row) return true;
    const course = $(row).find('td[data-col="course"]').data('course');
    return course === courseFilter;
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

  const statusColIdx = $('td[data-col="status"]').first().index();
  const $noticeEl = $('<div id="hidden-filter-notice" class="small text-muted w-100"></div>');
  $($tables.table().container()).find('.dataTables_info').closest('.col-6').append($noticeEl);

  const $teachersTable = $('.js-teachersTable').DataTable();

  $(".custom-checkbox").on("change", () => {
      $tables.draw();
  });

  $('#courseFilter').on('change', () => {
      $tables.draw();
  });
  $tables.on('draw', function() {
      $('[data-toggle="tooltip"]').tooltip('dispose');
      $('[data-toggle="tooltip"]').tooltip();
      updateHiddenResultsNotice($teachersTable, statusColIdx);
  });
});
