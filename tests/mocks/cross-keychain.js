const passwordStore = new Map();

export function getPassword(service, account) {
  const key = `${service}:${account}`;
  const password = passwordStore.get(key);
  
  if (password === undefined) {
    return Promise.reject(new Error('Password not found'));
  }
  
  return Promise.resolve(password);
}

export function setPassword(service, account, password) {
  const key = `${service}:${account}`;
  passwordStore.set(key, password);
  return Promise.resolve();
}

export function deletePassword(service, account) {
  const key = `${service}:${account}`;
  const existed = passwordStore.has(key);
  
  if (!existed) {
    return Promise.reject(new Error('Password not found'));
  }
  
  passwordStore.delete(key);
  return Promise.resolve();
}

export function clearStore() {
  passwordStore.clear();
}

export default {
  getPassword,
  setPassword,
  deletePassword,
  clearStore
};
