import express from 'express';
import AdminForth from 'adminforth';
import usersResource from "./resources/adminuser.js";
import { fileURLToPath } from 'url';
import path from 'path';
import { Filters } from 'adminforth';
import apartmentsResource from "./resources/apartments.js";

const ADMIN_BASE_URL = '';

export const admin = new AdminForth({
  baseUrl: ADMIN_BASE_URL,
  auth: {
    usersResourceId: 'adminuser',
    usernameField: 'email',
    passwordHashField: 'password_hash',
    rememberMeDays: 30,
    loginBackgroundImage: 'https://images.unsplash.com/photo-1534239697798-120952b76f2b?q=80&w=3389&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    loginBackgroundPosition: '1/2',
    loginPromptHTML: async () => {
      const adminforthUserExists = await admin.resource("adminuser").count(Filters.EQ('email', 'adminforth')) > 0;
      if (adminforthUserExists) {
        return "Please use <b>adminforth</b> as username and <b>adminforth</b> as password";
      }
    },
    userMenuSettingsPages: []
  },
  customization: {
    brandName: "myadmin",
    title: "myadmin",
    favicon: '@@/assets/favicon.png',
    brandLogo: '@@/assets/logo.svg',
    datesFormat: 'DD MMM',
    timeFormat: 'HH:mm a',
    showBrandNameInSidebar: true,
    showBrandLogoInSidebar: true,
    emptyFieldPlaceholder: '-',
    styles: {
      colors: {
        light: {
          primary: '#1a56db',
          sidebar: { main: '#f9fafb', text: '#213045' },
        },
        dark: {
          primary: '#82ACFF',
          sidebar: { main: '#1f2937', text: '#9ca3af' },
        }
      }
    },
  },
  dataSources: [
    {
      id: 'maindb',
      url: `${process.env.DATABASE_URL}`
    },
  ],
  resources: [
    usersResource,
    apartmentsResource,
  ],
  menu: [
    {
      label: 'Core',
      icon: 'flowbite:brain-solid',
      open: true,
      children: [
        {
          homepage: true,
          label: 'Apartments',
          icon: 'flowbite:home-solid',
          resourceId: 'aparts',
        },
      ]
    },
    { type: 'gap' },
    { type: 'divider' },
    { type: 'heading', label: 'SYSTEM' },
    {
      label: 'Users',
      icon: 'flowbite:user-solid',
      resourceId: 'adminuser'
    }
  ],
});

async function seedDatabase() {
  if (await admin.resource('aparts').count() > 0) {
    return
  }
  for (let i = 0; i < 100; i++) {
    await admin.resource('aparts').create({
      id: `${i}`,
      title: `Apartment ${i}`,
      square_meter: (Math.random() * 100).toFixed(1),
      price: (Math.random() * 10000).toFixed(2),
      number_of_rooms: Math.floor(Math.random() * 4) + 1,
      description: 'Next gen apartments',
      created_at: (new Date(Date.now() - Math.random() * 60 * 60 * 24 * 14 * 1000)).toISOString(),
      listed: i % 2 == 0,
      country: `${['US', 'DE', 'FR', 'GB', 'NL', 'IT', 'ES', 'DK', 'PL', 'UA'][Math.floor(Math.random() * 10)]}`
    });
  };
};

if (fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const app = express();
  app.use(express.json());

  const port = 3500;

  admin.bundleNow({ hotReload: process.env.NODE_ENV === 'development' }).then(() => {
    console.log('Bundling AdminForth SPA done.');
  });

  admin.express.serve(app);

  admin.discoverDatabases().then(async () => {
    if (await admin.resource('adminuser').count() === 0) {
      await admin.resource('adminuser').create({
        email: 'adminforth',
        password_hash: await AdminForth.Utils.generatePasswordHash('adminforth'),
        role: 'superadmin',
      });
    }
    await seedDatabase();
  });

  admin.express.listen(port, () => {
    console.log(`\n⚡ AdminForth is available at http://localhost:${port}${ADMIN_BASE_URL}\n`);
  });
}
