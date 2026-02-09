interface ComparisonRow {
  feature: string;
  lecsy: string | boolean;
  otter: string | boolean;
  notta?: string | boolean;
}

interface ComparisonTableProps {
  rows: ComparisonRow[];
  includeNotta?: boolean;
}

export default function ComparisonTable({ rows, includeNotta = false }: ComparisonTableProps) {
  const renderValue = (value: string | boolean) => {
    if (typeof value === 'boolean') {
      return value ? (
        <span className="text-green-600 font-semibold">✅</span>
      ) : (
        <span className="text-gray-400">❌</span>
      );
    }
    return <span className="text-gray-700">{value}</span>;
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse bg-white rounded-xl shadow-lg overflow-hidden">
        <thead>
          <tr className="bg-gradient-to-r from-blue-600 to-blue-500 text-white">
            <th className="px-6 py-4 text-left font-semibold">Feature</th>
            <th className="px-6 py-4 text-center font-semibold">Lecsy</th>
            <th className="px-6 py-4 text-center font-semibold">Otter.ai</th>
            {includeNotta && (
              <th className="px-6 py-4 text-center font-semibold">Notta</th>
            )}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr
              key={index}
              className={index % 2 === 0 ? 'bg-gray-50' : 'bg-white'}
            >
              <td className="px-6 py-4 font-medium text-gray-900">{row.feature}</td>
              <td className="px-6 py-4 text-center">{renderValue(row.lecsy)}</td>
              <td className="px-6 py-4 text-center">{renderValue(row.otter)}</td>
              {includeNotta && (
                <td className="px-6 py-4 text-center">
                  {row.notta !== undefined ? renderValue(row.notta) : '-'}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
