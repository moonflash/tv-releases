import React, { useEffect, useState } from 'react';

const ReleasesPage = () => {
  const [countries, setCountries] = useState([]);
  const [networks, setNetworks] = useState([]);
  const [filters, setFilters] = useState({
    country: '',
    network: '',
    start_date: '',
    end_date: ''
  });
  const [releases, setReleases] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Fetch countries on mount
  useEffect(() => {
    fetch('/api/v1/countries')
      .then((res) => res.json())
      .then((data) => setCountries(data))
      .catch((err) => console.error('Failed to fetch countries', err));
  }, []);

  // Fetch networks when country filter changes
  useEffect(() => {
    if (filters.country) {
      fetch(`/api/v1/networks?country=${encodeURIComponent(filters.country)}`)
        .then((res) => res.json())
        .then((data) => setNetworks(data))
        .catch((err) => console.error('Failed to fetch networks', err));
    } else {
      setNetworks([]);
    }
  }, [filters.country]);

  // Fetch releases whenever filters change
  useEffect(() => {
    fetchReleases();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filters]);

  const fetchReleases = () => {
    setLoading(true);
    setError(null);

    const params = new URLSearchParams();
    if (filters.country) params.append('country', filters.country);
    if (filters.network) params.append('network', filters.network);
    if (filters.start_date) params.append('start_date', filters.start_date);
    if (filters.end_date) params.append('end_date', filters.end_date);
    params.append('per_page', '100');

    fetch(`/api/v1/releases?${params.toString()}`)
      .then((res) => res.json())
      .then((data) => {
        setReleases(data.releases || []);
        setLoading(false);
      })
      .catch((err) => {
        console.error('Failed to fetch releases', err);
        setError('Failed to load releases');
        setLoading(false);
      });
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFilters((prev) => ({
      ...prev,
      [name]: value
    }));
  };

  const renderFilters = () => (
    <div className="filters">
      <label>
        Country:
        <select name="country" value={filters.country} onChange={handleInputChange}>
          <option value="">All</option>
          {countries.map((c) => (
            <option key={c.shortcode} value={c.shortcode}>
              {c.name}
            </option>
          ))}
        </select>
      </label>

      <label>
        Network:
        <select
          name="network"
          value={filters.network}
          onChange={handleInputChange}
          disabled={!networks.length}
        >
          <option value="">All</option>
          {networks.map((n) => (
            <option key={n.id} value={n.id}>
              {n.name}
            </option>
          ))}
        </select>
      </label>

      <label>
        From:
        <input
          type="date"
          name="start_date"
          value={filters.start_date}
          onChange={handleInputChange}
        />
      </label>

      <label>
        To:
        <input
          type="date"
          name="end_date"
          value={filters.end_date}
          onChange={handleInputChange}
        />
      </label>
    </div>
  );

  const renderReleases = () => {
    if (loading) return <p>Loading releases…</p>;
    if (error) return <p className="error">{error}</p>;
    if (!releases.length) return <p>No releases found.</p>;

    return (
      <ul className="releases-list">
        {releases.map((rel) => (
          <li key={rel.id} className="release-item">
            <strong>{rel.episode.show.title}</strong> — S{rel.episode.season_number}E{rel.episode.episode_number} —{' '}
            {rel.air_date} {rel.air_time}
            <br />
            Network: {rel.episode.show.network.name} ({rel.episode.show.network.country.shortcode})
          </li>
        ))}
      </ul>
    );
  };

  return (
    <div className="releases-page">
      <h2>TV Releases</h2>
      {renderFilters()}
      {renderReleases()}
    </div>
  );
};

export default ReleasesPage; 