import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import App from './App.jsx';

function mockFetch(responses) {
  global.fetch = vi.fn(async () => {
    const next = responses.shift();
    return {
      ok: next.status < 400,
      status: next.status,
      json: async () => next.body,
    };
  });
}

afterEach(() => vi.restoreAllMocks());

test('renders items from the API', async () => {
  mockFetch([{ status: 200, body: [{ id: 1, title: 'Write Terraform', done: false }] }]);
  render(<App />);
  expect(await screen.findByText('Write Terraform')).toBeInTheDocument();
});

test('shows empty state', async () => {
  mockFetch([{ status: 200, body: [] }]);
  render(<App />);
  expect(await screen.findByText('Nothing here yet.')).toBeInTheDocument();
});

test('adds an item', async () => {
  mockFetch([
    { status: 200, body: [] },
    { status: 201, body: { id: 2, title: 'Ship to AKS', done: false } },
  ]);
  render(<App />);
  await screen.findByText('Nothing here yet.');
  await userEvent.type(screen.getByPlaceholderText('What needs doing?'), 'Ship to AKS');
  await userEvent.click(screen.getByRole('button', { name: 'Add' }));
  expect(await screen.findByText('Ship to AKS')).toBeInTheDocument();
  expect(global.fetch).toHaveBeenLastCalledWith('/api/items', expect.objectContaining({ method: 'POST' }));
});

test('shows API errors', async () => {
  mockFetch([{ status: 500, body: { error: 'internal server error' } }]);
  render(<App />);
  await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('internal server error'));
});
