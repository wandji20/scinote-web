/* global tableColRowName notTurbolinksPreview */

(function() {
  'use strict';

  function initWelcomeModal() {
    $('#shareable-link-welcome-modal').modal('show');
  }

  function initStepsExpandCollapse() {
    $(document).on('click', '#steps-collapse-btn', function() {
      $('.step-container .collapse').collapse('hide');
    });

    $(document).on('click', '#steps-expand-btn', function() {
      $('.step-container .collapse').collapse('show');
    });
  }

  function initStepComments() {
    $(document).on('click', '.shareable-link-open-comments-sidebar', function(e) {
      e.preventDefault();
      $('.comments-sidebar').removeClass('open');
      $('.showing-comments').removeClass('showing-comments');

      $($(this).data('objectTarget')).addClass('open');
      $(`#stepContainer${$(this).data('objectId')}`).addClass('showing-comments');
    });

    $(document).on('click', '.comments-sidebar .close-btn', function() {
      $('.showing-comments').removeClass('showing-comments');
    });
  }

  function initStepAttachments() {
    $(document).on('click', '.shareable-file-preview-link, .shareable-gallery-switcher', function(e) {
      e.preventDefault();
      $('.modal-file-preview.in').modal('hide');
      $($(`.modal-file-preview[data-object-id=${$(this).data('id')}]`)).modal('show');
    });
  }

  function initializeHandsonTable(el) {
    var input = el.siblings('input.hot-table-contents');
    var inputObj = JSON.parse(input.attr('value'));
    var metadataJson = el.siblings('input.hot-table-metadata');
    var data = inputObj.data;
    var metadata;

    metadata = JSON.parse(metadataJson.val() || '{}');
    el.handsontable({
      disableVisualSelection: true,
      rowHeaders: tableColRowName.tableRowHeaders(metadata.plateTemplate),
      colHeaders: tableColRowName.tableColHeaders(metadata.plateTemplate),
      editor: false,
      copyPaste: false,
      formulas: true,
      data: data,
      cell: metadata.cells || []
    });
  }

  function initMyModuleProtocolShow() {
    const myModule = $('#details-container').attr('data-shareable-link');
    if (!sessionStorage.getItem(`my_module_shareable_link_${myModule}`)) {
      sessionStorage.setItem(`my_module_shareable_link_${myModule}`, myModule);
      initWelcomeModal();
    }
    initStepsExpandCollapse();
    initStepComments();
    initStepAttachments();

    $('.hot-table-container').each(function() {
      initializeHandsonTable($(this));
    });
  }

  if (notTurbolinksPreview()) {
    initMyModuleProtocolShow();
  }
}());
