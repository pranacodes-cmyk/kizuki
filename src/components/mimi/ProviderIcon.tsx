export function ProviderIcon({ provider }: { provider: 'google' | 'apple' }) {
  return provider === 'google' ? (
    <svg aria-hidden="true" viewBox="0 0 24 24" className="h-[22px] w-[22px] shrink-0">
      <path className="fill-google-blue" d="M21.6 12.2c0-.7-.1-1.5-.2-2.2H12v4.2h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.8 3-4.3 3-7.5Z"/>
      <path className="fill-google-green" d="M12 22c2.7 0 5-.9 6.6-2.3l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22Z"/>
      <path className="fill-google-yellow" d="M6.4 14.1a6 6 0 0 1 0-4.2V7.3H3.1a10 10 0 0 0 0 9.4l3.3-2.6Z"/>
      <path className="fill-google-red" d="M12 5.8c1.5 0 2.8.5 3.9 1.5l2.9-2.9A9.6 9.6 0 0 0 12 2a10 10 0 0 0-8.9 5.3l3.3 2.6A6 6 0 0 1 12 5.8Z"/>
    </svg>
  ) : (
    <svg aria-hidden="true" viewBox="0 0 24 24" className="h-6 w-6 shrink-0 fill-current">
      <path d="M17.1 12.5c0-2 1.6-3 1.7-3.1-.9-1.4-2.3-1.5-2.8-1.6-1.2-.1-2.4.8-3 .8-.7 0-1.7-.8-2.8-.7-1.4 0-2.7.8-3.4 2-1.4 2.4-.4 5.9 1 7.9.6 1 1.4 2 2.4 2 .9 0 1.3-.6 2.6-.6 1.2 0 1.6.6 2.7.6s1.8-1 2.4-1.9c.8-1.1 1.1-2.2 1.1-2.3-.1 0-1.9-.7-1.9-3.1ZM15 6.5c.5-.7 1-1.7.9-2.7-.8 0-1.9.6-2.5 1.3-.6.6-1.1 1.6-1 2.6 1 .1 2-.5 2.6-1.2Z"/>
    </svg>
  );
}