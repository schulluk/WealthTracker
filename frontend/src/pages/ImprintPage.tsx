import { ExternalLink, Heart, Code, AlertCircle } from 'lucide-react';

export default function ImprintPage() {
  return (
    <div className="imprint-page">
      <h1>Imprint</h1>

      <div className="imprint-grid">
        {/* Developer Info */}
        <section className="imprint-section">
          <h2>
            <Code size={20} />
            Developer
          </h2>
          <p className="developer-name">Lukas Schulze</p>
        </section>

        {/* Open Source */}
        <section className="imprint-section">
          <h2>
            <Code size={20} />
            Open Source
          </h2>
          <p>
            This project is open source and licensed under the MIT License.
            Contributions are welcome!
          </p>
          <div className="link-list">
            <a
              href="https://github.com/lsgd/wealth"
              target="_blank"
              rel="noopener noreferrer"
              className="imprint-link"
            >
              <Code size={16} />
              Source Code
              <ExternalLink size={14} />
            </a>
            <a
              href="https://github.com/lsgd/wealth/issues"
              target="_blank"
              rel="noopener noreferrer"
              className="imprint-link"
            >
              <AlertCircle size={16} />
              Report Issues
              <ExternalLink size={14} />
            </a>
          </div>
        </section>

        {/* Support */}
        <section className="imprint-section">
          <h2>
            <Heart size={20} />
            Support the Project
          </h2>
          <p>
            If you find this app useful, consider supporting its development
            with a donation.
          </p>
          <a
            href="https://paypal.me/lukasschulze"
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-primary donate-button"
          >
            <Heart size={16} />
            Donate via PayPal
            <ExternalLink size={14} />
          </a>
        </section>
      </div>

      <footer className="imprint-footer">
        <p>Made with love for personal finance tracking</p>
      </footer>
    </div>
  );
}
