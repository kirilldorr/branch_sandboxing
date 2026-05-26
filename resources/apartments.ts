import { AdminForthDataTypes, AdminForthResourceInput } from 'adminforth';

export default {
  dataSource: 'maindb',
  table: 'apartments',
  resourceId: 'aparts', // resourceId is defaulted to table name but you can redefine it like this e.g. 
  // in case of same table names from different data sources
  label: 'Apartments',   // label is defaulted to table name but you can change it
  recordLabel: (r) => `🏡 ${r.title}`,
  columns: [
    {
      name: 'id',
      type: AdminForthDataTypes.STRING,
      label: 'Identifier',  // if you wish you can redefine label, defaulted to uppercased name
      showIn: { // show column in filter and in show page
        list: false,
        edit: false,
        create: false,
      },
      primaryKey: true,
      fillOnCreate: ({ initialRecord, adminUser }) => Math.random().toString(36).substring(7),  // called during creation to generate content of field, initialRecord is values user entered, adminUser object of user who creates record
    },
    {
      name: 'title',
      required: true,
      showIn: { all: true },  // all available options
      type: AdminForthDataTypes.STRING,
      maxLength: 255,  // you can set max length for string fields
      minLength: 3,  // you can set min length for string fields
    },
    {
      name: 'created_at',
      type: AdminForthDataTypes.DATETIME,
      allowMinMaxQuery: true,
      showIn: { create: false },
      fillOnCreate: ({ initialRecord, adminUser }) => (new Date()).toISOString(),
    },
    {
      name: 'price',
      inputSuffix: 'USD', // you can add a suffix to an input field that will be displayed when creating or editing records
      allowMinMaxQuery: true,  // use better experience for filtering e.g. date range, set it only if you have index on this column or if you sure there will be low number of rows
      editingNote: 'Price is in USD',  // you can put a note near field on editing or creating page
    },
    {
      name: 'square_meter',
      label: 'Square',
      allowMinMaxQuery: true,
      minValue: 1,  // you can set min /max value for number columns so users will not be able to enter more/less
      maxValue: 1000,
    },
    {
      name: 'number_of_rooms',
      allowMinMaxQuery: true,
      enum: [
        { value: 1, label: '1 room' },
        { value: 2, label: '2 rooms' },
        { value: 3, label: '3 rooms' },
        { value: 4, label: '4 rooms' },
        { value: 5, label: '5 rooms' },
      ],
    },
    {
      name: 'description',
      sortable: false,
      showIn: { list: false },
    },
    {
      name: 'country',
      enum: [{
        value: 'US',
        label: 'United States'
      }, {
        value: 'DE',
        label: 'Germany'
      }, {
        value: 'FR',
        label: 'France'
      }, {
        value: 'GB',
        label: 'United Kingdom'
      }, {
        value: 'NL',
        label: 'Netherlands'
      }, {
        value: 'IT',
        label: 'Italy'
      }, {
        value: 'ES',
        label: 'Spain'
      }, {
        value: 'DK',
        label: 'Denmark'
      }, {
        value: 'PL',
        label: 'Poland'
      }, {
        value: 'UA',
        label: 'Ukraine'
      }, {
        value: null,
        label: 'Not defined'
      }],
    },
    {
      name: 'listed',
      required: true,  // will be required on create/edit
    },
    {
      name: 'realtor_id',
      foreignResource: {
        resourceId: 'adminuser',
        searchableFields: ["id", "email"], // fields available for search in filter
      }
    }
  ],
  options: {
    listPageSize: 12,
    allowedActions: {
      edit: true,
      delete: true,
      show: true,
      filter: true,
    },
  },
} as AdminForthResourceInput;