/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  // When this brand starts consuming the private API client, add:
  // transpilePackages: ['@monster/nextapi'],
};

export default nextConfig;
