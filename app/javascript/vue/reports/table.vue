<template>
  <div class="h-full">
    <DataTable :columnDefs="columnDefs"
               :tableId="'ReportTemplates'"
               :dataUrl="dataSource"
               :reloadingTable="reloadingTable"
               :toolbarActions="toolbarActions"
               :actionsUrl="actionsUrl"
               @tableReloaded="reloadingTable = false"
               @update_pdf="updatePdf"
               @delete="deleteReport"
               @update_docx="updateDocx"
               @save_pdf_to_repository="savePdfToRepository"
      />
  </div>
  <ConfirmationModal
    :title="deleteModal.title"
    :description="deleteModal.description"
    confirmClass="btn btn-danger"
    :confirmText="i18n.t('repositories.index.modal_delete.delete')"
    ref="deleteModal"
  ></ConfirmationModal>
  <SaveToInventoryModal
    v-if="reportToSave"
    :report="reportToSave"
    :repositoriesUrl="availableRepositoriesUrl"
    :columnsUrl="availableColumnsUrl"
    :rowsUrl="availableRowsUrl"
    ref="saveToInventoryModal"/>
</template>

<script>
/* global HelperModule */

import axios from '../../packs/custom_axios.js';

import DataTable from '../shared/datatable/table.vue';
import DocxRenderer from './renderers/docx.vue';
import PdfRenderer from './renderers/pdf.vue';
import ConfirmationModal from '../shared/confirmation_modal.vue';
import SaveToInventoryModal from './modals/save_to_inventory.vue';

export default {
  name: 'ReportsTable',
  components: {
    DataTable,
    DocxRenderer,
    PdfRenderer,
    ConfirmationModal,
    SaveToInventoryModal
  },
  props: {
    dataSource: {
      type: String,
      required: true
    },
    actionsUrl: {
      type: String,
      required: true
    },
    createUrl: {
      type: String
    },
    availableRepositoriesUrl: {
      type: String
    },
    availableColumnsUrl: {
      type: String
    },
    availableRowsUrl: {
      type: String
    }
  },
  data() {
    return {
      reloadingTable: false,
      deleteModal: {
        title: '',
        description: ''
      },
      reportToSave: null,
      columnDefs: [
        {
          field: 'project_name',
          headerName: this.i18n.t('projects.reports.index.thead_project_name'),
          sortable: true
        }, {
          field: 'name',
          headerName: this.i18n.t('projects.reports.index.thead_name'),
          sortable: true,
          cellRenderer: ({ data: { name } }) => `<span title="${name}">${name}</span>`
        }, {
          field: 'code',
          headerName: this.i18n.t('projects.reports.index.thead_id'),
          sortable: true
        }, {
          field: 'pdf_file',
          headerName: this.i18n.t('projects.reports.index.pdf'),
          sortable: true,
          cellRenderer: 'PdfRenderer'
        }, {
          field: 'docx_file',
          headerName: this.i18n.t('projects.reports.index.docx'),
          sortable: true,
          cellRenderer: 'DocxRenderer'
        }, {
          field: 'created_by_name',
          headerName: this.i18n.t('projects.reports.index.thead_created_by'),
          sortable: true
        }, {
          field: 'modified_by_name',
          headerName: this.i18n.t('projects.reports.index.thead_last_modified_by'),
          sortable: true
        }, {
          field: 'created_at',
          headerName: this.i18n.t('projects.reports.index.thead_created_at'),
          sortable: true
        }, {
          field: 'updated_at',
          headerName: this.i18n.t('projects.reports.index.thead_updated_at'),
          sortable: true
        }
      ]
    };
  },
  computed: {
    toolbarActions() {
      const left = [];
      if (this.createUrl) {
        left.push({
          name: 'create',
          icon: 'sn-icon sn-icon-new-task',
          label: this.i18n.t('projects.reports.index.new'),
          type: 'link',
          path: this.createUrl,
          buttonStyle: 'btn btn-primary'
        });
      }
      return {
        left,
        right: []
      };
    }
  },
  methods: {
    updateTable() {
      this.reloadingTable = true;
    },
    updatePdf(_event, rows) {
      const [report] = rows;
      axios.post(report.urls.generate_pdf)
        .then(() => {
          this.updateTable();
        });
    },
    updateDocx(_event, rows) {
      const [report] = rows;
      axios.post(report.urls.generate_docx)
        .then(() => {
          this.updateTable();
        });
    },
    async deleteReport(event, rows) {
      this.deleteModal.title = this.i18n.t('projects.reports.index.modal_delete.head_title');
      this.deleteModal.description = this.i18n.t('projects.reports.index.modal_delete.message');

      const ok = await this.$refs.deleteModal.show();
      if (ok) {
        axios.post(event.path, { report_ids: rows.map((row) => row.id) }).then((response) => {
          this.updateTable();
          HelperModule.flashAlertMsg(response.data.message, 'success');
        });
      }
    },
    savePdfToRepository(_event, rows) {
      const [report] = rows;
      this.reportToSave = report;
    }
  }
};

</script>
